<script setup>
const steps = [
  {
    id: 'pinch',
    title: 'Pinch to start.',
    description: 'Bring your thumb and index finger together to start a gesture.',
  },
  {
    id: 'move',
    title: 'Move to scroll.',
    description: 'Keep the pinch held and move your hand up or down to scroll the page.',
  },
  {
    id: 'release',
    title: 'Release to stop.',
    description: 'Open your fingers to stop scrolling. Pinch again from a comfortable position.',
  },
]

const permissions = [
  {
    id: 'camera',
    title: 'Camera',
    description: 'Your Mac’s camera tracks the gesture. Hand tracking runs on your Mac, and Slight Motion saves no video.',
  },
  {
    id: 'accessibility',
    title: 'Accessibility',
    description: 'macOS asks for permission so Slight Motion can send ordinary scroll events to the app you’re reading in.',
  },
  {
    id: 'stop',
    title: 'Stops when you let go',
    description: 'The prototype is designed to wait for a steady pinch and stop as soon as you release it or tracking is lost.',
  },
]

const questions = [
  {
    title: 'Do I need a Safari extension?',
    answer: 'Slight Motion is designed as a Mac menu bar app. Safari can receive the same kind of scroll events a mouse wheel sends, so you can use it without an extension.',
  },
  {
    title: 'How does Slight Motion know what to scroll?',
    answer: 'Leave your pointer over the page or pane you want to scroll before you start. macOS usually sends scroll events to whatever is under the pointer.',
  },
  {
    title: 'What can I scroll?',
    answer: 'The prototype is designed for apps and panes that already respond to a mouse wheel, such as a Safari article or a PDF viewer.',
  },
  {
    title: 'Does the demo use my camera?',
    answer: 'The demo on this site uses an animated hand you can control with buttons. Only the native Mac app needs camera permission to see your gesture.',
  },
]
</script>

<template>
  <section id="how-it-works" class="section-shell how-section" aria-labelledby="how-title">
    <div class="section-intro">
      <div>
        <p class="section-index"><span>01</span> / HOW IT WORKS</p>
        <h2 id="how-title">One gesture.<br />Three small moves.</h2>
      </div>
      <p class="section-lede">Leave the pointer over what you’re reading. Then let your hand take over.</p>
    </div>

    <ol class="step-grid" role="list">
      <li v-for="(step, index) in steps" :key="step.id" class="step-card">
        <div class="step-visual" aria-hidden="true">
          <span class="step-number">0{{ index + 1 }}</span>
          <svg class="step-diagram" viewBox="0 0 144 105" fill="none" focusable="false">
            <g v-if="step.id === 'pinch'">
              <circle cx="72" cy="53" r="39" class="diagram-guide" />
              <circle cx="72" cy="53" r="24" class="diagram-guide" />
              <path d="M28 53h88m-44-44v88" class="diagram-axis" />
              <path d="M26 21c13 1 22 5 32 15l10 11M118 85c-13-1-22-5-32-15L76 59" class="diagram-motion" />
              <path d="m57 46 11 1-1-11m20 24-11-1 1 11" class="diagram-motion" />
              <circle cx="72" cy="53" r="7" class="diagram-dot" />
            </g>
            <g v-else-if="step.id === 'move'">
              <path d="M40 23h64M40 53h64M40 83h64" class="diagram-axis" />
              <circle cx="72" cy="53" r="23" class="diagram-guide" />
              <circle cx="72" cy="53" r="7" class="diagram-dot" />
              <path d="M72 38V13m0 55v25m-7-72 7-8 7 8M65 85l7 8 7-8" class="diagram-motion" />
              <path d="M38 36h10m-5-5v10m54 29h10m-5-5v10" class="diagram-guide" />
            </g>
            <g v-else>
              <circle cx="72" cy="53" r="39" class="diagram-guide" />
              <circle cx="72" cy="53" r="24" class="diagram-guide" />
              <path d="M28 53h88m-44-44v88" class="diagram-axis" />
              <path d="M63 44 43 24m20 10v10H53m28 18 20 20m-20-10V62h10" class="diagram-axis" />
              <path d="m58 39-15-15m0 11V24h11m32 43 15 15m0-11v11H90" class="diagram-motion" />
              <circle cx="72" cy="53" r="6" class="diagram-guide release-dot" />
            </g>
          </svg>
        </div>
        <div class="step-copy">
          <h3>{{ step.title }}</h3>
          <p>{{ step.description }}</p>
        </div>
      </li>
    </ol>
  </section>

  <section id="privacy" class="privacy-section" aria-labelledby="privacy-title">
    <div class="section-shell privacy-layout">
      <div>
        <p class="section-index"><span>02</span> / PRIVACY &amp; PERMISSIONS</p>
        <h2 id="privacy-title">Your gestures stay on your Mac.</h2>
        <p class="section-lede">Turn gesture scrolling on from the menu bar when you’re ready to read.</p>
      </div>
      <ul class="permission-list" role="list">
        <li v-for="permission in permissions" :key="permission.id">
          <span class="permission-icon" aria-hidden="true">
            <svg viewBox="0 0 24 24" fill="none" focusable="false">
              <path
                v-if="permission.id === 'camera'"
                d="M3 7.5A1.5 1.5 0 0 1 4.5 6h9A1.5 1.5 0 0 1 15 7.5v9a1.5 1.5 0 0 1-1.5 1.5h-9A1.5 1.5 0 0 1 3 16.5zM15 10l6-3v10l-6-3"
              />
              <path
                v-else-if="permission.id === 'accessibility'"
                d="M12 10a3 3 0 1 0 0-6 3 3 0 0 0 0 6Zm0 0v5m-4 5 4-5 4 5M5 11l7 2 7-2"
              />
              <path v-else d="M7.5 7.5h9v9h-9zM12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20Z" />
            </svg>
          </span>
          <div>
            <h3>{{ permission.title }}</h3>
            <p>{{ permission.description }}</p>
          </div>
        </li>
      </ul>
    </div>
  </section>

  <section id="faq" class="section-shell faq-section" aria-labelledby="faq-title">
    <div>
      <p class="section-index"><span>03</span> / THE DETAILS</p>
      <h2 id="faq-title">Good to know.</h2>
    </div>
    <div class="question-list">
      <details v-for="question in questions" :key="question.title" class="question">
        <summary>
          <span>{{ question.title }}</span>
          <svg viewBox="0 0 24 24" fill="none" aria-hidden="true" focusable="false">
            <path d="M6 12h12" />
            <path class="question-plus" d="M12 6v12" />
          </svg>
        </summary>
        <p>{{ question.answer }}</p>
      </details>
    </div>
  </section>

  <section id="availability" class="section-shell availability-section" aria-labelledby="availability-title">
    <div class="availability-panel">
      <div>
        <p class="section-index"><span>04</span> / AVAILABILITY</p>
        <h2 id="availability-title">A small idea for your Mac.</h2>
        <p>Slight Motion is a macOS prototype. Try the browser demo to see how the gesture would work in the native app.</p>
      </div>
      <a class="availability-link" href="#gesture-demo">
        Try the gesture demo
        <svg viewBox="0 0 24 24" fill="none" aria-hidden="true" focusable="false">
          <path d="M5 12h14m-6-6 6 6-6 6" />
        </svg>
      </a>
    </div>
  </section>
</template>

<style scoped>
.section-shell {
  width: calc(min(100%, var(--frame)) - 2 * var(--gutter));
  margin-inline: auto;
}

section {
  scroll-margin-block-start: 6.5rem;
}

h2,
h3,
p {
  margin: 0;
}

h2,
h3 {
  font-family: 'Space Grotesk', sans-serif;
}

h2 {
  font-size: clamp(2.5rem, 5.2vw, 5rem);
  line-height: .99;
  font-weight: 600;
  letter-spacing: -.067em;
  text-wrap: balance;
}

.section-index,
.step-number {
  font-family: 'IBM Plex Mono', ui-monospace, monospace;
  font-size: .72rem;
  font-weight: 600;
  line-height: 1.4;
  letter-spacing: .075em;
}

.section-index {
  margin-bottom: 1.25rem;
}

.section-index span {
  margin-inline-end: .23em;
  color: #5030d7;
}

.section-lede {
  max-width: 29ch;
  color: #5d5966;
  font-size: clamp(1rem, 1.4vw, 1.25rem);
  line-height: 1.5;
}

.how-section {
  padding-block: clamp(64px, 8vw, 118px);
}

.section-intro {
  display: grid;
  grid-template-columns: minmax(0, 1.65fr) minmax(0, 1fr);
  align-items: end;
  gap: 1.5rem 2.5rem;
  margin-bottom: clamp(2rem, 4vw, 3.5rem);
}

.section-intro .section-lede {
  margin-bottom: .2rem;
}

.step-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 1rem;
  padding: 0;
  margin: 0;
  list-style: none;
}

.step-card {
  overflow: hidden;
  border: 1px solid #dedbe3;
  border-radius: 1.1rem;
  background: #fffefa;
}

.step-visual {
  position: relative;
  display: grid;
  min-height: clamp(7rem, 12vw, 11rem);
  place-items: center;
  border-bottom: 1px solid #dedbe3;
  background: #efedfc;
}

.step-number {
  position: absolute;
  top: 1rem;
  left: 1.15rem;
  color: #5030d7;
}

.step-diagram {
  display: block;
  width: clamp(6.5rem, 10vw, 9rem);
  height: auto;
}

.diagram-guide,
.diagram-axis {
  stroke: #9b8acc;
}

.diagram-axis {
  stroke-dasharray: 3 4;
}

.diagram-motion {
  stroke: #5030d7;
  stroke-width: 2;
  stroke-linecap: round;
  stroke-linejoin: round;
}

.diagram-dot {
  fill: #5030d7;
}

.release-dot {
  stroke: #5030d7;
  stroke-dasharray: 2 2;
}

.step-copy {
  padding: clamp(1rem, 2.2vw, 2rem);
}

.step-copy h3,
.permission-list h3 {
  font-size: clamp(1.1rem, 1.8vw, 1.65rem);
  font-weight: 600;
  line-height: 1.15;
  letter-spacing: -.035em;
}

.step-copy p,
.permission-list p {
  margin-top: .5rem;
  color: #5d5966;
  line-height: 1.55;
}

.privacy-section {
  padding-block: clamp(64px, 8vw, 118px);
  color: #f8f7f3;
  background: #221e2a;
}

.privacy-layout {
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(0, .91fr);
  gap: clamp(2.5rem, 7vw, 8rem);
}

.privacy-layout h2 {
  max-width: 12ch;
  text-wrap: initial;
}

.privacy-layout .section-index {
  color: #f8f7f3;
}

.privacy-layout .section-index span {
  color: #bfb2ff;
}

.privacy-layout .section-lede {
  margin-top: 1.35rem;
  color: #cfccd5;
}

.permission-list {
  display: grid;
  padding: 0;
  margin: 0;
  list-style: none;
  border-top: 1px solid #484250;
}

.permission-list li {
  display: grid;
  grid-template-columns: auto 1fr;
  align-items: start;
  gap: .9rem;
  padding-block: 1.15rem;
  border-bottom: 1px solid #484250;
}

.permission-list p {
  margin-top: .3rem;
  color: #cfccd5;
}

.permission-icon {
  display: grid;
  width: 2.6rem;
  aspect-ratio: 1;
  place-items: center;
  border-radius: .7rem;
  color: #dbd1ff;
  background: #3b3056;
}

.permission-icon svg {
  width: 1.25rem;
  height: 1.25rem;
  stroke: currentColor;
  stroke-width: 1.5;
  stroke-linecap: round;
  stroke-linejoin: round;
}

.faq-section {
  display: grid;
  grid-template-columns: minmax(0, .7fr) minmax(0, 1fr);
  gap: clamp(2rem, 5vw, 6rem);
  padding-block: clamp(64px, 8vw, 118px);
}

.faq-section h2 {
  text-wrap: initial;
}

.question-list {
  border-top: 1px solid #dedbe3;
}

.question {
  border-bottom: 1px solid #dedbe3;
}

.question summary {
  display: flex;
  align-items: center;
  justify-content: space-between;
  min-height: 3.5rem;
  gap: .8rem;
  padding: .9rem .25rem;
  color: #1e1b25;
  font-size: clamp(1rem, 1.4vw, 1.2rem);
  font-weight: 600;
  list-style: none;
  cursor: pointer;
}

.question summary::-webkit-details-marker {
  display: none;
}

.question summary:hover {
  color: #5030d7;
}

.question summary svg {
  flex: none;
  width: 1.2rem;
  height: 1.2rem;
  stroke: #5030d7;
  stroke-width: 1.6;
  stroke-linecap: round;
}

.question[open] .question-plus {
  visibility: hidden;
}

.question p {
  padding: 0 1.55rem 1.1rem .25rem;
  color: #5d5966;
  line-height: 1.55;
}

.availability-section {
  margin-bottom: clamp(36px, 5vw, 72px);
}

.availability-panel {
  display: flex;
  flex-wrap: wrap;
  align-items: end;
  justify-content: space-between;
  gap: 1.5rem 2.5rem;
  padding: clamp(1.75rem, 4.5vw, 4.5rem);
  border-radius: 1.25rem;
  background: #e9e7ff;
}

.availability-panel h2 {
  font-size: clamp(2.15rem, 4.3vw, 4rem);
  text-wrap: initial;
}

.availability-panel p:not(.section-index) {
  max-width: 47ch;
  margin-top: .95rem;
  color: #504960;
  line-height: 1.55;
}

.availability-link {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: .6rem;
  min-height: 3rem;
  padding: .65rem 1rem;
  border: 1px solid transparent;
  border-radius: .65rem;
  color: #fff;
  background: #5030d7;
  font-weight: 600;
  text-align: center;
  text-decoration: none;
}

.availability-link:hover {
  background: #3e22b5;
}

.availability-link svg {
  flex: none;
  width: 1.15rem;
  height: 1.15rem;
  stroke: currentColor;
  stroke-width: 1.75;
  stroke-linecap: round;
  stroke-linejoin: round;
}

.question summary:focus-visible,
.availability-link:focus-visible {
  outline: 2px solid #5030d7;
  outline-offset: 3px;
}

@media (max-width: 760px) {
  .section-intro,
  .privacy-layout,
  .faq-section {
    grid-template-columns: 1fr;
  }

  .section-lede {
    max-width: 34ch;
  }
}

@media (max-width: 580px) {
  .step-grid {
    grid-template-columns: 1fr;
    gap: .75rem;
  }

  .step-card {
    display: grid;
    grid-template-columns: 7rem minmax(0, 1fr);
  }

  .step-visual {
    min-height: 6.75rem;
    border-right: 1px solid #dedbe3;
    border-bottom: 0;
  }

  .step-number {
    top: .55rem;
    left: .65rem;
  }

  .step-diagram {
    width: 5.75rem;
  }

  .step-copy {
    align-self: center;
  }
}

@media (max-width: 350px) {
  .step-card {
    grid-template-columns: 5.25rem minmax(0, 1fr);
  }

  .step-diagram {
    width: 4.7rem;
  }
}
</style>
