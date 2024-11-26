# Capacitor component

We don't do localization for this component because the Image can't be pre-loaded.
The manifest type of the image is `application/vnd.cncf.flux.config.v1+json`. So the
pre-loading fails. This is a cheat kind of. The main manifest then does come from ghcr
so technically it would be possible to do so, but it's irrelevant from the demo's perspective.

The important bit is the Podinfo app.