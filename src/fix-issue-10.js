class InflightOperationLock {
  constructor(options = {}) {
    this.baseDelayMs = options.baseDelayMs ?? 500;
    this.maxDelayMs = options.maxDelayMs ?? 15000;
    this.activeLock = null;
    this.cleanups = new Set();
  }

  track(fn) {
    this.cleanups.add(fn);
    return () => this.cleanups.delete(fn);
  }

  releaseAll() {
    for (const fn of this.cleanups) {
      try {
        fn();
      } catch (_) {}
    }
    this.cleanups.clear();
  }

  async runAtomic(taskFn) {
    if (this.activeLock) return this.activeLock;
    this.activeLock = (async () => {
      try {
        this.releaseAll();
        return await taskFn();
      } finally {
        this.activeLock = null;
      }
    })();
    return this.activeLock;
  }
}

module.exports = { InflightOperationLock };
