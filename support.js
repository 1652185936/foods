(function () {
  'use strict';

  if (window.__localDcRuntimeLoaded) return;
  window.__localDcRuntimeLoaded = true;

  class LocalDCLogic {
    setState(update) {
      const patch = typeof update === 'function' ? update(this.state) : update;
      if (patch && typeof patch === 'object') {
        this.state = Object.assign({}, this.state, patch);
      }
      if (this.__requestRender) this.__requestRender();
    }
  }

  if (typeof window.DCLogic !== 'function') {
    window.DCLogic = LocalDCLogic;
  }

  function readValue(context, expression) {
    const key = expression.trim();
    if (key === 'true') return true;
    if (key === 'false') return false;
    if (key === 'null') return null;

    const parts = key.split('.');
    let value = context[parts.shift()];
    for (const part of parts) {
      if (value == null) return undefined;
      value = value[part];
    }
    return value;
  }

  function resolveTemplate(raw, context) {
    const exact = raw.match(/^\s*\{\{\s*([^{}]+?)\s*\}\}\s*$/);
    if (exact) return readValue(context, exact[1]);

    return raw.replace(/\{\{\s*([^{}]+?)\s*\}\}/g, function (_, expression) {
      const value = readValue(context, expression);
      if (value == null || typeof value === 'function') return '';
      return String(value);
    });
  }

  function renderNode(node, context, handlers, sequence) {
    if (node.nodeType === Node.TEXT_NODE) {
      node.nodeValue = resolveTemplate(node.nodeValue, context);
      return;
    }

    if (node.nodeType !== Node.ELEMENT_NODE) return;

    const tag = node.tagName.toLowerCase();

    if (tag === 'sc-if') {
      const visible = Boolean(resolveTemplate(node.getAttribute('value') || '', context));
      const replacement = document.createDocumentFragment();
      if (visible) {
        for (const child of Array.from(node.childNodes)) {
          const clone = child.cloneNode(true);
          renderNode(clone, context, handlers, sequence);
          replacement.appendChild(clone);
        }
      }
      node.replaceWith(replacement);
      return;
    }

    if (tag === 'sc-for') {
      const list = resolveTemplate(node.getAttribute('list') || '', context);
      const alias = node.getAttribute('as');
      const replacement = document.createDocumentFragment();

      if (alias && list && typeof list[Symbol.iterator] === 'function') {
        for (const item of list) {
          const itemContext = Object.create(context);
          itemContext[alias] = item;
          for (const child of Array.from(node.childNodes)) {
            const clone = child.cloneNode(true);
            renderNode(clone, itemContext, handlers, sequence);
            replacement.appendChild(clone);
          }
        }
      }

      node.replaceWith(replacement);
      return;
    }

    for (const attribute of Array.from(node.attributes)) {
      const name = attribute.name;
      const lowerName = name.toLowerCase();

      if (lowerName === 'onclick') {
        const handler = resolveTemplate(attribute.value, context);
        node.removeAttribute(name);
        if (typeof handler === 'function') {
          const id = 'dc-handler-' + sequence.value++;
          handlers.set(id, handler);
          node.setAttribute('data-dc-click', id);
        }
        continue;
      }

      if (lowerName === 'style-active' || lowerName === 'key' || lowerName.indexOf('hint-') === 0) {
        node.removeAttribute(name);
        continue;
      }

      const value = resolveTemplate(attribute.value, context);
      if (value == null || value === false) node.removeAttribute(name);
      else node.setAttribute(name, String(value));
    }

    for (const child of Array.from(node.childNodes)) {
      renderNode(child, context, handlers, sequence);
    }
  }

  function showRuntimeError(error) {
    console.error('[Local DC runtime]', error);
    const panel = document.createElement('div');
    panel.setAttribute('role', 'alert');
    panel.style.cssText = 'position:fixed;left:16px;right:16px;bottom:16px;z-index:9999;padding:12px 14px;border-radius:8px;background:#7f1d1d;color:#fff;font:600 13px/1.5 system-ui,sans-serif;box-shadow:0 8px 28px rgba(0,0,0,.25)';
    panel.textContent = 'The local interaction runtime failed to start. Open the browser console for details.';
    document.body.appendChild(panel);
  }

  function startRuntime() {
    const root = document.querySelector('x-dc');
    const componentScript = document.querySelector('script[data-dc-script]');
    if (!root || !componentScript) return;

    try {
      const helmet = root.querySelector(':scope > helmet');
      if (helmet) {
        while (helmet.firstChild) document.head.appendChild(helmet.firstChild);
        helmet.remove();
      }

      const template = document.createElement('template');
      template.innerHTML = root.innerHTML;

      const Component = new Function(
        'DCLogic',
        componentScript.textContent + '\nreturn Component;'
      )(window.DCLogic);

      const component = new Component();
      let handlers = new Map();
      let renderQueued = false;
      let mounted = false;

      function render() {
        renderQueued = false;
        const activeScreen = root.querySelector('.app-screen');
        const previousScroll = activeScreen ? activeScreen.scrollTop : 0;
        const values = component.renderVals();
        const context = Object.assign(Object.create(null), values);
        const fragment = template.content.cloneNode(true);
        const nextHandlers = new Map();
        const sequence = { value: 1 };

        for (const child of Array.from(fragment.childNodes)) {
          renderNode(child, context, nextHandlers, sequence);
        }

        handlers = nextHandlers;
        root.replaceChildren(fragment);
        const nextScreen = root.querySelector('.app-screen');
        if (nextScreen) nextScreen.scrollTop = previousScroll;

        if (!mounted) {
          mounted = true;
          requestAnimationFrame(function () {
            root.classList.add('dc-runtime-ready');
          });
        }
      }

      component.__requestRender = function () {
        if (renderQueued) return;
        renderQueued = true;
        queueMicrotask(render);
      };

      root.addEventListener('click', function (event) {
        const target = event.target instanceof Element
          ? event.target.closest('[data-dc-click]')
          : null;
        if (!target || !root.contains(target)) return;

        const handler = handlers.get(target.getAttribute('data-dc-click'));
        if (typeof handler !== 'function') return;
        event.preventDefault();
        handler(event);
      });

      document.addEventListener('keydown', function (event) {
        if (event.key === 'Escape' && component.state.camStep !== 'idle') {
          if (typeof component.closeCam === 'function') component.closeCam();
          else component.setState({ camStep: 'idle' });
        }
      });

      window.addEventListener('beforeunload', function () {
        if (typeof component.componentWillUnmount === 'function') {
          component.componentWillUnmount();
        }
      });

      const runtimeStyle = document.createElement('style');
      runtimeStyle.textContent = 'x-dc{display:block}x-dc.dc-runtime-ready .app-screen{animation:none!important}';
      document.head.appendChild(runtimeStyle);

      window.__dcComponent = component;
      render();
      if (typeof component.componentDidMount === 'function') {
        component.componentDidMount();
      }
    } catch (error) {
      showRuntimeError(error);
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', startRuntime, { once: true });
  } else {
    startRuntime();
  }
})();
