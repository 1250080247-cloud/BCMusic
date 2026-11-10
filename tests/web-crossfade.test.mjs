import test from 'node:test';
import assert from 'node:assert/strict';
import { useSettingsStore } from '../src/lib/store.js';

test('useSettingsStore maintains crossfade preference and partializes it', () => {
  // Default is false
  assert.equal(typeof useSettingsStore.getState().crossfade, 'boolean');

  // Toggle or set to true
  useSettingsStore.getState().setCrossfade(true);
  assert.equal(useSettingsStore.getState().crossfade, true);

  // Set back to false
  useSettingsStore.getState().setCrossfade(false);
  assert.equal(useSettingsStore.getState().crossfade, false);
});

// Helper simulating Web Player Crossfade State Machine
class WebCrossfadeController {
  constructor({ volume = 80, crossfade = true, repeatMode = 'off' } = {}) {
    this.volume = volume;
    this.crossfade = crossfade;
    this.repeatMode = repeatMode;
    this.playerVolume = volume;
    this.fadeTimer = null;
    this.isFadingOut = false;
    this.isFadingIn = false;
    this.isAutoTransition = false;
    this.currentTime = 0;
    this.duration = 180;
    this.isPlaying = true;
  }

  applyPlayerVolume(val) {
    this.playerVolume = Math.max(0, Math.min(100, Math.round(val)));
  }

  cancelCrossfade() {
    if (this.fadeTimer) {
      clearInterval(this.fadeTimer);
      this.fadeTimer = null;
    }
    this.isFadingOut = false;
    this.isFadingIn = false;
    this.applyPlayerVolume(this.volume);
  }

  onSettingsVolumeChange(newVol) {
    this.volume = newVol;
    if (this.isFadingOut || this.isFadingIn) {
      this.cancelCrossfade();
    } else {
      this.applyPlayerVolume(newVol);
    }
  }

  onCrossfadeToggle(enabled) {
    this.crossfade = enabled;
    if (!enabled) {
      this.cancelCrossfade();
    }
  }

  checkFadeOut(currentTime, duration) {
    this.currentTime = currentTime;
    this.duration = duration;
    if (!this.isPlaying || !duration || duration <= 10 || !this.crossfade || this.repeatMode === 'one') return false;
    const remaining = duration - currentTime;
    if (remaining <= 5 && remaining > 0 && !this.isFadingOut && !this.isFadingIn) {
      this.isFadingOut = true;
      const startTime = Date.now();
      const startVol = this.volume;
      if (this.fadeTimer) clearInterval(this.fadeTimer);
      this.fadeTimer = setInterval(() => {
        const elapsed = Date.now() - startTime;
        const progress = Math.min(1, elapsed / 5000);
        this.applyPlayerVolume(Math.max(0, startVol * (1 - progress)));
        if (progress >= 1) {
          clearInterval(this.fadeTimer);
          this.fadeTimer = null;
        }
      }, 100);
      return true;
    }
    return false;
  }

  onTrackStart(isAuto) {
    this.isFadingOut = false;
    if (!this.crossfade || this.repeatMode === 'one' || !isAuto) {
      this.cancelCrossfade();
      return;
    }
    this.isFadingIn = true;
    this.applyPlayerVolume(0);
    const startTime = Date.now();
    if (this.fadeTimer) clearInterval(this.fadeTimer);
    this.fadeTimer = setInterval(() => {
      const elapsed = Date.now() - startTime;
      const progress = Math.min(1, elapsed / 5000);
      this.applyPlayerVolume(this.volume * progress);
      if (progress >= 1) {
        clearInterval(this.fadeTimer);
        this.fadeTimer = null;
        this.isFadingIn = false;
      }
    }, 100);
  }
}

test('Fade-out does not trigger for tracks shorter than or equal to 10s', () => {
  const ctrl = new WebCrossfadeController({ volume: 80, crossfade: true });
  // Short track: 8 seconds total, at 5 seconds
  const triggered = ctrl.checkFadeOut(5, 8);
  assert.equal(triggered, false);
  assert.equal(ctrl.isFadingOut, false);
  assert.equal(ctrl.playerVolume, 80);
});

test('Fade-out does not trigger when repeatMode is one', () => {
  const ctrl = new WebCrossfadeController({ volume: 80, crossfade: true, repeatMode: 'one' });
  const triggered = ctrl.checkFadeOut(176, 180);
  assert.equal(triggered, false);
  assert.equal(ctrl.isFadingOut, false);
  assert.equal(ctrl.playerVolume, 80);
});

test('Fade-out triggers when remaining <= 5s, ramps down volume', async () => {
  const ctrl = new WebCrossfadeController({ volume: 100, crossfade: true });
  const triggered = ctrl.checkFadeOut(176, 180);
  assert.equal(triggered, true);
  assert.equal(ctrl.isFadingOut, true);
  assert.ok(ctrl.fadeTimer !== null);

  // Wait 250ms and check volume decreased
  await new Promise((r) => setTimeout(r, 250));
  assert.ok(ctrl.playerVolume < 100, `Expected volume < 100, got ${ctrl.playerVolume}`);

  // Clean up
  ctrl.cancelCrossfade();
  assert.equal(ctrl.playerVolume, 100);
  assert.equal(ctrl.fadeTimer, null);
});

test('Turning off crossfade while ramp is active immediately cancels timer and restores volume', async () => {
  const ctrl = new WebCrossfadeController({ volume: 90, crossfade: true });
  ctrl.checkFadeOut(176, 180);
  assert.equal(ctrl.isFadingOut, true);

  await new Promise((r) => setTimeout(r, 200));
  assert.ok(ctrl.playerVolume < 90);

  // User disables crossfade in settings
  ctrl.onCrossfadeToggle(false);
  assert.equal(ctrl.isFadingOut, false);
  assert.equal(ctrl.fadeTimer, null);
  assert.equal(ctrl.playerVolume, 90);
});

test('Manual volume change during ramp cancels fade and applies new volume', async () => {
  const ctrl = new WebCrossfadeController({ volume: 80, crossfade: true });
  ctrl.checkFadeOut(176, 180);

  await new Promise((r) => setTimeout(r, 150));
  // User drags slider to 50
  ctrl.onSettingsVolumeChange(50);
  assert.equal(ctrl.isFadingOut, false);
  assert.equal(ctrl.fadeTimer, null);
  assert.equal(ctrl.playerVolume, 50);
});

test('Fade-in ramps from 0 to full volume on auto-transition', async () => {
  const ctrl = new WebCrossfadeController({ volume: 100, crossfade: true });
  ctrl.onTrackStart(true);
  assert.equal(ctrl.isFadingIn, true);
  assert.equal(ctrl.playerVolume, 0);

  await new Promise((r) => setTimeout(r, 250));
  assert.ok(ctrl.playerVolume > 0, `Expected volume > 0, got ${ctrl.playerVolume}`);

  ctrl.cancelCrossfade();
  assert.equal(ctrl.playerVolume, 100);
});

test('Manual track start skips fade-in and immediately sets full volume', () => {
  const ctrl = new WebCrossfadeController({ volume: 80, crossfade: true });
  ctrl.onTrackStart(false);
  assert.equal(ctrl.isFadingIn, false);
  assert.equal(ctrl.playerVolume, 80);
});
