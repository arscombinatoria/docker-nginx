# docker-nginx

Custom NGINX image that enables the Brotli module by compiling dynamic modules with an Ubuntu-based build stage and layering them onto the official `nginx` image. Dependabot is configured to keep the base image up to date.

## Why this image?
- **Version-safe Brotli**: The build stage reads the nginx version from the upstream image and compiles Brotli modules against the exact same release.
- **Lean runtime**: Only the compiled modules and a small Brotli config are copied into the final image; build tooling stays in the builder layer.
- **Automated updates**: Dependabot bumps the `nginx` tag so rebuilds track upstream security releases without manual changes.

## Build

```bash
docker build -t custom-nginx-brotli .
```

The Dockerfile automatically aligns the Brotli modules to the nginx version from the base image, and Dependabot will bump that base image tag as new releases appear.

## Run
Start a container with your site configuration mounted in:

```bash
docker run -d --name custom-nginx \
  -p 8080:80 \
  -v $(pwd)/nginx.conf:/etc/nginx/nginx.conf:ro \
  -v $(pwd)/conf.d:/etc/nginx/conf.d:ro \
  custom-nginx-brotli
```

The image injects a `brotli.conf` snippet that enables Brotli with a reasonable compression level and common MIME types. If you want to tweak those settings, mount your own file at `/etc/nginx/conf.d/brotli.conf` to override the defaults.

## Verifying Brotli is loaded
Check the loaded modules inside a running container:

```bash
docker exec custom-nginx nginx -V 2>&1 | grep -i brotli
```

You should see both `ngx_http_brotli_filter_module` and `ngx_http_brotli_static_module` listed as dynamic modules.

## Development notes
- The builder image installs the toolchain and pulls `google/ngx_brotli` with submodules before compiling modules via `./configure --with-compat --add-dynamic-module=../ngx_brotli`.
- Only the resulting `.so` files and a small configuration snippet are copied into the final image, keeping it close in size to the upstream `nginx` image.
- If you update the base nginx version manually, no other Dockerfile edits are required; the build step automatically targets the detected version.
