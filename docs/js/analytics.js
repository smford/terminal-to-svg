/**
 * Google Analytics 4 (GA4) Analytics Module for terminal-to-svg
 *
 * Provides safe event dispatching, environment detection, and user interaction tracking.
 */

(function () {
  'use strict';

  var GA_MEASUREMENT_ID = 'terminal-to-svg';

  // Verify and guard window.dataLayer and gtag
  window.dataLayer = window.dataLayer || [];
  if (typeof window.gtag !== 'function') {
    window.gtag = function () {
      window.dataLayer.push(arguments);
    };
  }

  /**
   * Determine display mode (PWA standalone vs standard browser)
   */
  function getDisplayMode() {
    if (window.matchMedia && window.matchMedia('(display-mode: standalone)').matches) {
      return 'standalone';
    }
    if (window.navigator && window.navigator.standalone === true) {
      return 'standalone';
    }
    return 'browser';
  }

  /**
   * Safe wrapper for event tracking
   * @param {string} eventName
   * @param {Object} [params]
   */
  function trackEvent(eventName, params) {
    try {
      if (typeof window.gtag === 'function') {
        var eventParams = Object.assign(
          {
            app_name: 'terminal-to-svg',
            display_mode: getDisplayMode(),
            timestamp: new Date().toISOString()
          },
          params || {}
        );
        window.gtag('event', eventName, eventParams);
      }
    } catch (err) {
      // Intentionally suppressed to avoid impacting user experience if ad-blocker or network error
      if (console && typeof console.debug === 'function') {
        console.debug('[analytics] Failed to track event:', eventName, err);
      }
    }
  }

  /**
   * Track manual page views (especially for single-page apps or docs anchors)
   * @param {string} [pagePath]
   */
  function trackPageView(pagePath) {
    var path = pagePath || window.location.pathname + window.location.hash;
    trackEvent('page_view', {
      page_path: path,
      page_title: document.title
    });
  }

  // Export analytics helpers to window.TermToSvgAnalytics
  window.TermToSvgAnalytics = {
    trackEvent: trackEvent,
    trackPageView: trackPageView,
    trackCopyCommand: function (commandName) {
      trackEvent('copy_command', { command: commandName });
    },
    trackDownload: function (platform, version) {
      trackEvent('download_binary', { platform: platform, version: version });
    },
    trackExternalLink: function (url, label) {
      trackEvent('click_external_link', { destination_url: url, label: label });
    }
  };

  // Wire up DOM listeners once loaded
  document.addEventListener('DOMContentLoaded', function () {
    // Track initial page view
    trackPageView();

    // Attach tracking to copy buttons
    document.querySelectorAll('[data-copy-target], .copy-btn, .btn-copy').forEach(function (button) {
      button.addEventListener('click', function () {
        var text = button.getAttribute('data-clipboard-text') || button.innerText;
        window.TermToSvgAnalytics.trackCopyCommand(text.trim().substring(0, 50));
      });
    });

    // Attach tracking to release download links
    document.querySelectorAll('a[href*="/releases/download/"]').forEach(function (link) {
      link.addEventListener('click', function () {
        var href = link.getAttribute('href');
        var versionMatch = href.match(/releases\/download\/([^/]+)/);
        var version = versionMatch ? versionMatch[1] : 'unknown';
        window.TermToSvgAnalytics.trackDownload(href, version);
      });
    });

    // Attach tracking to documentation navigation
    document.querySelectorAll('nav a, .nav-link').forEach(function (link) {
      link.addEventListener('click', function () {
        var href = link.getAttribute('href');
        if (href && href.startsWith('#')) {
          trackEvent('nav_jump', { target_section: href });
        }
      });
    });
  });
})();
