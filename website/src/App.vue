<script setup>
import GestureDemo from './components/GestureDemo.vue'
import BelowFold from './components/BelowFold.vue'
import BrandMark from './components/BrandMark.vue'
</script>

<template>
  <a class="skip-link" href="#main-content">Skip to content</a>
  <header class="site-header" id="top">
    <div class="frame header-inner">
      <a class="wordmark" href="#top" aria-label="Slight Motion home">
        <BrandMark />
        <span>Slight<span class="wordmark-second"> Motion</span></span>
      </a>
      <nav class="site-nav" aria-label="Main">
        <a href="#how-it-works">How it works</a>
        <a href="#privacy">Privacy</a>
        <a href="#faq">FAQ</a>
      </nav>
      <a class="header-action" href="https://github.com/whitematteruk/Slight-Motion/releases/download/v1.0/Slight-Motion-macOS.zip">
        <span>Mac prototype</span>
        <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 18 18 6M8 6h10v10"/></svg>
      </a>
    </div>
  </header>

  <main id="main-content" tabindex="-1">
    <section class="hero frame" aria-labelledby="hero-title">
      <div class="hero-content">
        <p class="hero-kicker"><span aria-hidden="true"></span> A MENU BAR APP FOR MAC</p>
        <h1 id="hero-title">A little movement.<br><em>Keep reading.</em></h1>
        <p class="hero-description">Scroll articles, PDFs, and more with a simple pinch of your fingers. Slight Motion turns small hand gestures into scrolling on your Mac.</p>
        <a class="primary-action" href="#gesture-demo">
          Try the gesture demo
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 12h15m-6-6 6 6-6 6"/></svg>
        </a>
        <p class="hero-note">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3.5 6.5h12v11h-12a1.5 1.5 0 0 1-1.5-1.5v-8a1.5 1.5 0 0 1 1.5-1.5ZM15.5 10l5-3v10l-5-3M3 21 22 3"/></svg>
          The web demo doesn’t use your camera.
        </p>
      </div>
      <div class="hero-demo">
        <GestureDemo />
      </div>
    </section>

    <div class="capabilities frame">
      <div class="capabilities-inner" role="group" aria-label="At a glance">
        <span class="capability-heading">SMALL GESTURE.<br>LESS REACHING.</span>
        <span class="capability-item">
          <svg viewBox="0 0 24 24" aria-hidden="true"><rect x="3" y="4" width="18" height="13" rx="2"/><path d="M8 21h8m-4-4v4"/></svg>
          Made for macOS
        </span>
        <span class="capability-item">
          <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 22s7-3.7 7-10V5l-7-3-7 3v7c0 6.3 7 10 7 10Z"/><path d="m9 12 2 2 4-4"/></svg>
          On-device tracking
        </span>
        <span class="capability-item">
          <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="m15.5 8.5-2 5-5 2 2-5 5-2Z"/></svg>
          No Safari extension
        </span>
      </div>
    </div>

    <BelowFold />
  </main>

  <footer class="site-footer">
    <div class="frame footer-inner">
      <div class="footer-identity">
        <a class="wordmark" href="#top" aria-label="Slight Motion home">
          <BrandMark />
          <span>Slight<span class="wordmark-second"> Motion</span></span>
        </a>
        <p>A little movement. Keep reading.</p>
      </div>
      <nav class="footer-nav" aria-label="Footer">
        <a href="#how-it-works">How it works</a>
        <a href="#privacy">Privacy</a>
        <a href="#faq">FAQ</a>
      </nav>
      <a class="top-link" href="#top">
        Back to top
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 20V4M6 10l6-6 6 6"/></svg>
      </a>
    </div>
  </footer>
</template>
