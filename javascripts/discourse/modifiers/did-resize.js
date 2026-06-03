import { registerDestructor } from "@ember/destroyable";
import Modifier from "ember-modifier";

export default class DidResizeModifier extends Modifier {
  static observer = null;
  static handlers = null;

  element = null;
  handler = null;
  options = {};

  constructor(owner, args) {
    super(owner, args);

    if (!("ResizeObserver" in window)) {
      return;
    }

    if (!DidResizeModifier.observer) {
      DidResizeModifier.handlers = new WeakMap();
      DidResizeModifier.observer = new ResizeObserver((entries, observer) => {
        window.requestAnimationFrame(() => {
          for (const entry of entries) {
            const handler = DidResizeModifier.handlers?.get(entry.target);
            if (handler) {
              handler(entry, observer);
            }
          }
        });
      });
    }

    registerDestructor(this, (instance) => instance.unobserve());
  }

  modify(element, positional) {
    this.unobserve();

    this.element = element;

    const [handler, shouldListen = true, options] = positional;

    this.handler = handler;
    this.options = options ?? this.options;

    if (shouldListen) {
      this.observe();
    }
  }

  observe() {
    if (DidResizeModifier.observer && this.element) {
      this.addHandler();
      DidResizeModifier.observer.observe(this.element, this.options);
    }
  }

  addHandler() {
    if (this.element && this.handler) {
      DidResizeModifier.handlers?.set(this.element, this.handler);
    }
  }

  removeHandler() {
    if (this.element) {
      DidResizeModifier.handlers?.delete(this.element);
    }
  }

  unobserve() {
    if (this.element && DidResizeModifier.observer) {
      DidResizeModifier.observer.unobserve(this.element);
      this.removeHandler();
    }
  }
}
