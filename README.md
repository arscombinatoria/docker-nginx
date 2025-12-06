# docker-nginx

Custom NGINX image that enables the Brotli module by compiling dynamic modules with an Ubuntu-based build stage and layering them onto the official `nginx` image. Dependabot is configured to keep the base image up to date.

## Build

```bash
docker build -t custom-nginx-brotli .
```

The Dockerfile automatically aligns the Brotli modules to the nginx version from the base image, and Dependabot will bump that base image tag as new releases appear.
