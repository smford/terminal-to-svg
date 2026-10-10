package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/smford/golang-term2svg"
	"github.com/smford/golang-term2svg/pkg/termscreen"

	"golang.org/x/term"
)

var (
	version = "dev"
	commit  = "none"
	date    = "unknown"
)

func main() {
	showVer := flag.Bool("version", false, "Show version information")
	serveHealthz := flag.String("serve-healthz", "", "Run lightweight HTTP healthcheck daemon on given address (e.g. :8080) for container DAST / health checking")
	title := flag.String("title", "Terminal", "Title displayed on the window title bar")
	output := flag.String("o", "output.svg", "Output SVG file path (or '-' for stdout)")
	cols := flag.Int("cols", 0, "Terminal columns (default: detected or 140)")
	rows := flag.Int("rows", 0, "Terminal rows (default: detected or 30)")
	theme := flag.String("theme", "dark", "Theme: dark, light, catppuccin, nord, frameless")
	autoCrop := flag.Bool("auto-crop", false, "Shrink canvas to fit visible text")
	showCursor := flag.Bool("cursor", false, "Render blinking cursor")
	tabsStr := flag.String("tabs", "", "Comma-separated list of tabs (e.g. 'Dashboard,Config,Event Log')")
	activeTab := flag.Int("active-tab", 0, "Index of active tab (0-based)")
	cardHeader := flag.String("header", "", "Card subheader title")
	statusBadge := flag.String("badge", "", "Status badge text (e.g. 'FOLLOW: ON')")
	tmuxPane := flag.String("tmux", "", "Capture live tmux pane (e.g. '' for current, or '%1')")
	maskSecrets := flag.Bool("mask-secrets", false, "Auto-redact IP addresses, bearer tokens, passwords, and JWTs")
	tmplFile := flag.String("template", "", "Path to custom SVG template")
	timeoutSec := flag.Int("timeout", 15, "Timeout in seconds for executed command")

	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "Usage: %s [options] [-- command [args...]]\n\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "Modes:\n")
		fmt.Fprintf(os.Stderr, "  1. Live Screen:      %s [options]               (snapshots current open terminal)\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "  2. Snapshot command: %s [options] -- <command>  (runs command in virtual PTY)\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "  3. Pipe ANSI input:  cat log.txt | %s [options]\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "  4. Snapshot Tmux:    %s [options] -tmux \"%%1\"\n\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "Options:\n")
		flag.PrintDefaults()
	}

	flag.Parse()

	if *showVer {
		fmt.Printf("termtosvg version %s (commit: %s, built: %s)\n", version, commit, date)
		os.Exit(0)
	}

	if *serveHealthz != "" {
		mux := http.NewServeMux()
		mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusOK)
			_ = json.NewEncoder(w).Encode(map[string]string{
				"status":  "ok",
				"service": "termtosvg",
				"version": version,
			})
		})
		mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusOK)
			_ = json.NewEncoder(w).Encode(map[string]string{
				"status": "ok",
			})
		})
		server := &http.Server{
			Addr:              *serveHealthz,
			Handler:           mux,
			ReadHeaderTimeout: 5 * time.Second,
			ReadTimeout:       10 * time.Second,
			WriteTimeout:      10 * time.Second,
			IdleTimeout:       30 * time.Second,
		}
		fmt.Fprintf(os.Stderr, "termtosvg daemon listening on %s (health endpoint: /healthz)\n", *serveHealthz)
		// nosemgrep: go.lang.security.audit.net.use-tls.use-tls
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			fmt.Fprintf(os.Stderr, "Server error: %v\n", err)
			os.Exit(1)
		}
		os.Exit(0)
	}

	cmdArgs := flag.Args()

	terminalCols := *cols
	terminalRows := *rows

	// Auto-detect terminal size if not explicitly set
	if terminalCols <= 0 || terminalRows <= 0 {
		detCols, detRows, err := termscreen.GetCurrentTerminalSize()
		if err == nil && detCols > 0 && detRows > 0 {
			if terminalCols <= 0 {
				terminalCols = detCols
			}
			if terminalRows <= 0 {
				terminalRows = detRows
			}
		} else {
			if terminalCols <= 0 {
				terminalCols = term2svg.DefaultColumns
			}
			if terminalRows <= 0 {
				terminalRows = term2svg.DefaultRows
			}
		}
	}

	var customTmpl string
	if *tmplFile != "" {
		data, err := os.ReadFile(*tmplFile)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error reading template file: %v\n", err)
			os.Exit(1)
		}
		customTmpl = string(data)
	}

	var tabs []string
	if *tabsStr != "" {
		parts := strings.Split(*tabsStr, ",")
		for _, p := range parts {
			tabs = append(tabs, strings.TrimSpace(p))
		}
	}

	opts := term2svg.Options{
		Title:       *title,
		Columns:     terminalCols,
		Rows:        terminalRows,
		Theme:       *theme,
		AutoCrop:    *autoCrop,
		ShowCursor:  *showCursor,
		Tabs:        tabs,
		ActiveTab:   *activeTab,
		CardHeader:  *cardHeader,
		StatusBadge: *statusBadge,
		MaskSecrets: *maskSecrets,
		CustomTmpl:  customTmpl,
	}

	var svgContent string
	var err error

	// Determine input mode:
	if flag.Lookup("tmux") != nil && *tmuxPane != "" || isFlagPassed("tmux") {
		// Tmux snapshot mode
		svgContent, err = term2svg.TmuxToSVG(*tmuxPane, opts)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error capturing tmux pane: %v\n", err)
			os.Exit(1)
		}
	} else if len(cmdArgs) > 0 {
		// Command execution mode
		execCmd := cmdArgs[0]
		execArgs := cmdArgs[1:]

		if *title == "Terminal" {
			opts.Title = strings.Join(cmdArgs, " ")
		}

		ctx, cancel := context.WithTimeout(context.Background(), time.Duration(*timeoutSec)*time.Second)
		defer cancel()

		svgContent, err = term2svg.CommandToSVG(ctx, execCmd, execArgs, opts)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error running command: %v\n", err)
			os.Exit(1)
		}
	} else if !term.IsTerminal(int(os.Stdin.Fd())) {
		// Piped stdin mode
		svgContent, err = term2svg.ReaderToSVG(os.Stdin, opts)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error processing input: %v\n", err)
			os.Exit(1)
		}
	} else {
		// No command given and stdin is interactive terminal:
		// Automatically snapshot the currently open terminal screen!
		svgContent, err = term2svg.LiveTerminalToSVG(opts)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Could not automatically capture live terminal: %v\n\n", err)
			flag.Usage()
			os.Exit(1)
		}
	}

	// Write output
	if *output == "-" {
		_, _ = io.WriteString(os.Stdout, svgContent)
	} else {
		err = os.WriteFile(*output, []byte(svgContent), 0644)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error writing output file %s: %v\n", *output, err)
			os.Exit(1)
		}
		fmt.Fprintf(os.Stderr, "Successfully rendered terminal SVG -> %s\n", *output)
	}
}

func isFlagPassed(name string) bool {
	found := false
	flag.Visit(func(f *flag.Flag) {
		if f.Name == name {
			found = true
		}
	})
	return found
}
