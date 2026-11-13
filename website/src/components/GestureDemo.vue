<script setup>
import { computed, onBeforeUnmount, ref } from 'vue'

const steps = [
  { label: 'Pinch', description: 'Touch your thumb and index finger together.' },
  { label: 'Move', description: 'Keep the pinch held and move your hand up or down to scroll.' },
  { label: 'Release', description: 'Open your fingers to stop. Pinch again when you’re ready.' },
]

const pinchedHand = 'M151 196C146 180 130 176 117 167C103 157 89 140 79 128C73 121 73 114 78 109C84 103 92 107 100 114C111 124 119 130 127 125C135 120 134 110 127 100C121 91 112 88 102 92L86 101C77 105 70 102 67 95C64 87 71 80 80 76L104 65C118 59 132 62 145 68C150 59 159 59 166 64C172 58 181 60 188 66C197 62 208 67 212 77C222 96 224 124 217 147C212 163 207 178 211 196Z'
const openHand = 'M151 196C146 180 130 176 117 167C103 157 91 151 79 144C72 139 69 132 73 126C77 120 86 121 95 126C107 133 119 135 128 129C135 124 136 112 132 100C129 90 118 79 107 77L88 78C78 79 71 76 70 68C69 60 76 55 86 55L108 54C125 54 135 62 145 68C150 59 159 59 166 64C172 58 181 60 188 66C197 62 208 67 212 77C222 96 224 124 217 147C212 163 207 178 211 196Z'

const activeStep = ref(0)
const pinchCycle = ref(0)
const playback = ref('idle')
const isPlaying = computed(() => playback.value === 'playing')
const playLabel = computed(() => ({ idle: 'Play', playing: 'Pause', paused: 'Resume' })[playback.value])
const handPath = computed(() => activeStep.value === 2 ? openHand : pinchedHand)
let timer

function stopPlayback(state = 'idle') {
  clearTimeout(timer)
  playback.value = state
}

function selectStep(index) {
  stopPlayback()
  activeStep.value = index
  if (index === 0) pinchCycle.value += 1
}

function advancePlayback() {
  timer = setTimeout(() => {
    if (activeStep.value === steps.length - 1) {
      stopPlayback()
      return
    }

    activeStep.value += 1
    advancePlayback()
  }, 1900)
}

function togglePlayback() {
  if (isPlaying.value) {
    stopPlayback('paused')
    return
  }

  if (playback.value === 'idle') {
    activeStep.value = 0
    pinchCycle.value += 1
  }
  playback.value = 'playing'
  advancePlayback()
}

onBeforeUnmount(stopPlayback)
</script>

<template>
  <figure id="gesture-demo" class="gesture-demo" tabindex="-1" aria-label="Interactive gesture demo">
    <div class="demo-stage" :class="['phase-' + activeStep, { 'is-pinching': pinchCycle > 0 }]" aria-hidden="true">
      <div class="stage-label"><i></i> Gesture simulator</div>
      <div class="stage-count">0{{ activeStep + 1 }} <span>/</span> 03</div>

      <div class="hand-scene">
        <svg class="hand-svg" viewBox="0 0 244 228" fill="none">
          <g class="hand-guide" stroke="#8d7bdb" stroke-width="1.25">
            <path d="M28 34v139" stroke-dasharray="2 5" />
            <path d="m23 41 5-6 5 6m-10 125 5 6 5-6" stroke-linecap="round" stroke-linejoin="round" />
          </g>
          <g class="hand-body">
            <path
              class="hand-outline"
              :key="pinchCycle"
              :d="handPath"
              :style="{ d: 'path(\'' + handPath + '\')', '--hand-open': 'path(\'' + openHand + '\')' }"
              fill="#f9f6ff"
              stroke="#33216f"
              stroke-width="3"
              stroke-linejoin="round"
            />
            <path d="M145 68c8 3 13 9 16 16m5-20c7 4 11 10 13 16m9-14c5 3 9 9 10 14m-71 46c8 3 16 9 19 18" stroke="#33216f" stroke-width="2.2" stroke-linecap="round" />
            <path d="M148 188h65l3 23c.4 3-2 5-5 5h-58c-3 0-5-2-5-5z" fill="#b3a4f6" stroke="#33216f" stroke-width="3" stroke-linejoin="round" />
            <path d="M156 199h51" stroke="#6852b8" stroke-width="1.4" stroke-dasharray="2 3" stroke-linecap="round" />
            <g :key="'pinch-' + pinchCycle" class="pinch-mark" stroke="#6241e5">
              <circle cx="72" cy="103" r="19" stroke-width="1" stroke-dasharray="2 3" opacity=".65" />
              <circle cx="72" cy="103" r="10" stroke-width="1.5" />
              <circle cx="72" cy="103" r="4" fill="#6241e5" stroke="#f9f6ff" stroke-width="1.4" />
              <path d="M53 103h-7m26-19v-7" stroke-width="1.5" stroke-linecap="round" />
            </g>
            <g class="release-mark" stroke="#6241e5" stroke-width="1.6" stroke-linecap="round">
              <path d="m65 72-8-5m4 38H50m14 21-9 5" />
            </g>
          </g>
        </svg>
        <span class="gesture-label">{{ ['Pinch held', 'Scrolling', 'Released'][activeStep] }}</span>
      </div>

      <div class="browser-window">
        <div class="browser-chrome">
          <span class="browser-dots"><i></i><i></i><i></i></span>
          <span class="address-bar">
            <svg width="9" height="10" viewBox="0 0 10 11" fill="none">
              <rect x="2" y="4.5" width="6" height="5" rx="1" stroke="currentColor" />
              <path d="M3.5 4.5V3a1.5 1.5 0 1 1 3 0v1.5" stroke="currentColor" />
            </svg>
            fieldnotes.example
          </span>
        </div>
        <div class="browser-viewport">
          <div class="article-page">
            <div class="article-masthead"><span>Field Notes</span><span>VOL. 04</span></div>
            <span class="article-category">The outdoors</span>
            <p class="article-title">Take the<br />scenic route.</p>
            <svg class="article-art" viewBox="0 0 320 132" preserveAspectRatio="xMidYMid slice">
              <rect width="320" height="132" fill="#cbc5f2" />
              <circle cx="224" cy="46" r="25" fill="#e1eb96" />
              <path d="M0 88c53-29 92-36 136-16 36 17 54 16 100-6 29-14 57-16 84-7v73H0z" fill="#aa9cdd" />
              <path d="M0 111c47-44 97-57 146-30 45 24 67 16 99-1 24-13 52-14 75-6v58H0z" fill="#695a9c" />
              <path d="M0 123c53-19 98-23 147-4 30 11 59 9 95-10 28-14 54-17 78-8v31H0z" fill="#39325b" />
              <path d="M-4 103C60 66 97 63 145 85c42 18 59 16 106-6 25-12 49-14 74-6M-4 113c64-37 101-40 149-18 42 18 59 16 106-6 25-12 49-14 74-6M-4 123c64-37 101-40 149-18 42 18 59 16 106-6 25-12 49-14 74-6M-4 133c64-37 101-40 149-18 42 18 59 16 106-6 25-12 49-14 74-6" fill="none" stroke="#e1d7ff" opacity=".46" stroke-width=".7" />
            </svg>
            <p class="article-standfirst">A few good reasons to slow down and follow the trail a little further.</p>
            <div class="article-lines"><i></i><i></i><i></i><i></i></div>
          </div>
          <span class="scroll-track"><i></i></span>
        </div>
      </div>
    </div>

    <div class="demo-controls">
      <div class="demo-steps" role="group" aria-label="Gesture steps">
        <button
          v-for="(step, index) in steps"
          :key="step.label"
          type="button"
          :aria-pressed="activeStep === index"
          @click="selectStep(index)"
        >
          <span aria-hidden="true">0{{ index + 1 }}</span>{{ step.label }}
        </button>
      </div>
      <button class="play-demo" type="button" :aria-label="playLabel + ' demo'" @click="togglePlayback">
        <svg width="16" height="16" viewBox="0 0 16 16" fill="none" aria-hidden="true">
          <path v-if="isPlaying" d="M5.5 4v8m5-8v8" stroke="currentColor" stroke-width="2" stroke-linecap="round" />
          <path v-else d="M5 3.7c0-.6.7-1 1.2-.7l6.1 4.3c.5.3.5 1 0 1.4L6.2 13c-.5.3-1.2-.1-1.2-.7z" fill="currentColor" />
        </svg>
        <span aria-hidden="true">{{ playLabel }}</span>
      </button>
    </div>

    <figcaption class="demo-caption"><span role="status">{{ steps[activeStep].description }}</span></figcaption>
  </figure>
</template>

<style scoped>
.gesture-demo {
  container-type: inline-size;
  width: 100%;
  min-width: 0;
  margin: 0;
  scroll-margin-top: 7rem;
}

.demo-stage {
  position: relative;
  isolation: isolate;
  box-sizing: border-box;
  width: 100%;
  display: grid;
  grid-template-columns: minmax(0, .78fr) minmax(0, 1.22fr);
  align-items: center;
  gap: 1.2%;
  overflow: hidden;
  aspect-ratio: 1.74;
  min-height: 220px;
  padding: 11% 7.4% 6%;
  background:
    radial-gradient(ellipse at 85% 22%, #f3f0ff 0%, transparent 64%),
    #e9e5ff;
  border: 1px solid #d8d0f7;
  border-radius: 22px 22px 0 0;
}

.demo-stage::before {
  position: absolute;
  z-index: -1;
  inset: 0;
  background-image: radial-gradient(#8a73cc 1px, transparent 1px);
  background-size: 17px 17px;
  opacity: .17;
  mask-image: linear-gradient(to right, #000, transparent 80%);
  content: '';
}

.stage-label,
.stage-count {
  position: absolute;
  z-index: 1;
  top: clamp(12px, 3.7cqw, 27px);
  color: #4b3785;
  font-family: ui-monospace, SFMono-Regular, Consolas, monospace;
  font-size: clamp(9px, 1.62cqw, 12px);
  font-weight: 700;
  letter-spacing: .105em;
  line-height: 1.4;
  text-transform: uppercase;
}

.stage-label {
  display: flex;
  align-items: center;
  gap: 7px;
  left: 4.5%;
}

.stage-label i {
  width: 7px;
  height: 7px;
  background: #6545df;
  border-radius: 50%;
  box-shadow: 0 0 0 3px #d9cffd;
}

.stage-count {
  right: 4.5%;
}

.stage-count span {
  opacity: .65;
}

.hand-scene {
  position: relative;
  display: grid;
  align-self: stretch;
  place-items: center;
  min-width: 0;
}

.hand-svg {
  width: 115%;
  max-width: 280px;
  height: auto;
  margin: 0 -3% 12% -12%;
  overflow: visible;
}

.hand-body,
.pinch-mark,
.release-mark,
.hand-outline,
.article-page,
.scroll-track i {
  transition: transform 740ms cubic-bezier(.23, 1, .32, 1), opacity 250ms ease, d 430ms ease;
}

.hand-body {
  transform: translateY(0);
}

.phase-0.is-pinching .hand-outline {
  animation: close-hand 530ms cubic-bezier(.22, 1, .36, 1);
}

@keyframes close-hand {
  0%, 12% { d: var(--hand-open); }
}

.phase-0 .pinch-mark {
  transform-origin: 72px 103px;
  animation: pinch-signal 1000ms ease-out both;
}

@keyframes pinch-signal {
  0% { opacity: .2; transform: scale(1.38); }
  35% { opacity: 1; }
  100% { transform: scale(1); }
}

.release-mark,
.phase-2 .pinch-mark {
  opacity: 0;
}

.phase-2 .release-mark {
  opacity: 1;
}

.phase-1 .hand-body,
.phase-2 .hand-body {
  transform: translateY(20px);
}

.phase-1 .hand-guide {
  stroke: #6241e5;
}

.gesture-label {
  position: absolute;
  bottom: 1%;
  left: 50%;
  padding: .47em .86em;
  transform: translateX(-50%);
  border: 1px solid #d7cdf9;
  border-radius: 99px;
  background: #f6f2ff;
  color: #4b3785;
  font-family: ui-monospace, SFMono-Regular, Consolas, monospace;
  font-size: clamp(9px, 1.55cqw, 12px);
  font-weight: 650;
  line-height: 1;
  white-space: nowrap;
}

.browser-window {
  display: flex;
  flex-direction: column;
  align-self: stretch;
  min-width: 0;
  min-height: 0;
  overflow: hidden;
  border: 1px solid #c0b1e8;
  border-radius: clamp(8px, 2cqw, 13px);
  background: #fbf9f3;
  box-shadow: 0 19px 27px -19px #57458c8a, 0 4px 6px #48357615;
}

.browser-chrome {
  position: relative;
  z-index: 1;
  display: flex;
  flex: none;
  align-items: center;
  justify-content: center;
  min-height: clamp(22px, 5.25cqw, 36px);
  border-bottom: 1px solid #e4def1;
  background: #faf8ff;
}

.browser-dots {
  position: absolute;
  left: 4%;
  display: flex;
  gap: clamp(2px, .7cqw, 5px);
}

.browser-dots i {
  width: clamp(4px, 1cqw, 7px);
  height: clamp(4px, 1cqw, 7px);
  border-radius: 50%;
  background: #b9a9e7;
}

.browser-dots i:nth-child(2) {
  background: #d0c4ec;
}

.browser-dots i:nth-child(3) {
  background: #dcd3ee;
}

.address-bar {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 4px;
  width: 52%;
  height: 59%;
  padding: 1px 3px;
  border-radius: 4px;
  background: #ede7fa;
  color: #524775;
  font-size: clamp(6px, 1.2cqw, 10px);
  line-height: 1.15;
  white-space: nowrap;
}

.address-bar svg {
  flex: none;
  width: clamp(6px, 1.24cqw, 9px);
  height: auto;
}

.browser-viewport {
  position: relative;
  flex: 1;
  min-height: 0;
  overflow: hidden;
}

.article-page {
  padding: 5% 9% 15%;
  color: #25213b;
  transform: translateY(0);
}

.phase-1 .article-page,
.phase-2 .article-page {
  transform: translateY(-35%);
}

.article-masthead {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  padding-bottom: 4%;
  border-bottom: 1px solid #d7cfe2;
  font-family: Georgia, serif;
  font-size: clamp(11px, 2.3cqw, 18px);
  font-weight: 700;
  line-height: 1.1;
}

.article-masthead span + span,
.article-category {
  color: #584579;
  font-family: ui-monospace, SFMono-Regular, Consolas, monospace;
  font-size: clamp(6px, 1.12cqw, 9px);
  font-weight: 700;
  letter-spacing: .09em;
  line-height: 1;
  text-transform: uppercase;
}

.article-category {
  display: block;
  margin-top: 8%;
}

.article-title {
  margin: 2% 0 6%;
  font-family: Georgia, 'Times New Roman', serif;
  font-size: clamp(21px, 5.2cqw, 38px);
  font-weight: 700;
  letter-spacing: -.055em;
  line-height: .98;
}

.article-art {
  display: block;
  width: 100%;
  aspect-ratio: 2.43;
  border-radius: 3px;
}

.article-standfirst {
  margin: 5% 0;
  color: #4f4763;
  font-family: Georgia, serif;
  font-size: clamp(9px, 1.9cqw, 14px);
  line-height: 1.35;
}

.article-lines {
  display: grid;
  gap: clamp(3px, .9cqw, 6px);
}

.article-lines i {
  height: 2px;
  border-radius: 9px;
  background: #e3dce8;
}

.article-lines i:last-child {
  width: 76%;
}

.scroll-track {
  position: absolute;
  inset: 8% 2% 6% auto;
  width: 3px;
  border-radius: 5px;
  background: #e8e1f4;
}

.scroll-track i {
  display: block;
  width: 100%;
  height: 35%;
  border-radius: 5px;
  background: #a793df;
}

.phase-1 .scroll-track i,
.phase-2 .scroll-track i {
  transform: translateY(120%);
}

.demo-controls {
  display: flex;
  gap: clamp(6px, 1.2cqw, 12px);
  justify-content: space-between;
  align-items: center;
  padding: clamp(6px, 1.45cqw, 12px);
  border-radius: 0 0 20px 20px;
  background: #252033;
  color: #fff;
}

.demo-steps {
  display: grid;
  flex: 1 1 auto;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: clamp(3px, .65cqw, 7px);
}

.demo-controls button {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: clamp(3px, 1.2cqw, 9px);
  min-height: 44px;
  padding: 0 clamp(4px, 1.25cqw, 9px);
  border: 1px solid transparent;
  border-radius: 8px;
  background: transparent;
  color: #e1d9ee;
  font: inherit;
  font-size: clamp(11px, 2.15cqw, 15px);
  font-weight: 650;
  line-height: 1;
  cursor: pointer;
}

.demo-steps button span {
  color: #c0b1d7;
  font-family: ui-monospace, SFMono-Regular, Consolas, monospace;
  font-size: .78em;
}

.demo-steps button:hover {
  background: #3f3653;
}

.demo-steps button[aria-pressed='true'] {
  border-color: #9d8cce;
  background: #483a62;
  color: #fff;
}

.demo-steps button[aria-pressed='true'] span {
  color: #dfd0ff;
}

.demo-controls button:focus-visible {
  outline: 2px solid #e6ffab;
  outline-offset: 1px;
}

.demo-controls .play-demo {
  flex: 0 0 auto;
  min-width: clamp(75px, 17cqw, 101px);
  padding-inline: clamp(6px, 1.9cqw, 13px);
  border-color: #d9cbff;
  background: #e7ddff;
  color: #281950;
}

.play-demo:hover {
  background: #f3edff;
}

.play-demo svg {
  flex: none;
  width: 15px;
  height: 15px;
}

.demo-caption {
  min-height: 2.4em;
  margin-top: 10px;
  padding-inline: 2px;
  color: #554d62;
  font-size: clamp(.78rem, 2.1cqw, .9rem);
  line-height: 1.4;
}

@container (max-width: 390px) {
  .demo-stage {
    padding-inline: 5.5%;
    border-radius: 16px 16px 0 0;
  }

  .demo-controls {
    border-radius: 0 0 14px 14px;
  }

  .gesture-label {
    bottom: 6%;
  }

  .demo-controls .play-demo span {
    display: none;
  }

  .demo-controls .play-demo {
    min-width: 44px;
  }
}

@container (max-width: 285px) {
  .demo-steps button span {
    display: none;
  }
}

@media (prefers-reduced-motion: reduce) {
  .phase-0 .pinch-mark,
  .phase-0.is-pinching .hand-outline {
    animation: none;
  }

  .hand-body,
  .pinch-mark,
  .release-mark,
  .hand-outline,
  .article-page,
  .scroll-track i {
    transition: none;
  }
}
</style>
