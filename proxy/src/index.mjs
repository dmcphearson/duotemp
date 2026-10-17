import { handle } from "./proxy.mjs";

export default {
  async fetch(request, env, ctx) {
    return handle(request, {
      cache: caches.default,
      fetchUpstream: (url, init) => fetch(url, init),
      waitUntil: (promise) => ctx.waitUntil(promise),
    });
  },
};
