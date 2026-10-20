import { handle } from "./proxy.mjs";

export default {
  async fetch(request, env, ctx) {
    return handle(request, {
      cache: caches.default,
      fetchUpstream: (url, init) => fetch(url, init),
      waitUntil: (promise) => ctx.waitUntil(promise),
      attest: {
        // ATTEST_SECRET is a Worker secret; without it attestation is off and every request passes.
        secret: env.ATTEST_SECRET,
        appId: env.APP_ID,
        mode: env.ATTEST_MODE,
        log: (line) => console.log(line),
      },
    });
  },
};
