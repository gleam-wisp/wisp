![Wisp Logo][/assets/logo.svg]

# Wisp Documentation Site

Simple, static site, with the documentation content written in djot,
and generated to static HTML using Gleam. We use [TailwindCSS](https://tailwindcss.com/) 
for styling, and [Pagefind](https://pagefind.app/) to generate search documents to run in 
the front-end without needing a server. Unfortunately these both require 
us to bring in dependencies, but it's worth it to avoid reinventing the universe.

### Documentation structure
content/`{section}`/`{slug}`.djot 

### Building

```bash
gleam run # Build the static HTML content

# Can also use npm or Bun if you so prefer.
pnpm run build # Build the stylesheet and Pagefind content
```

Once the above has been run, the `dist` directory can be served as-is.
