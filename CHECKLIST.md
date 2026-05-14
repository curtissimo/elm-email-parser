# Curtissimo.EmailParser Checklist

Go through the **Initial setup**. When you want to publish, go through the
**Before publishing** and **Publishing** steps.

## Initial setup

- [X] Create an empty **GitLab** repo `curtissimo/elm-email-parser`
- [X] Set up the GitHub mirror
  - Go to GitHub and create a repository for `curtissimo/elm-email-parser`
  - Get personal token with repository push privileges
  - Go to your GitLab repo and set up mirroring to the GitHub repo
- [X] Initialize the local Git repository (`git init`)
- [X] Set the `origin` remote
  - If you like using ssh, `npm run git:set-remote`
  - If you like using HTTP, `npm run git:set-remote:http`

## Developing

You do you with your development process.

If you'd like, you can run `npm start` which will start up the main
[`./examples/src/index.html`](./examples/src/index.html) in a hot-reload
server. That way, you can get real-time feedback while building your
example.

## Before publishing

- [X] Write documentation and preview it using `npm run docs`
- [X] Make sure the correct modules are exposed in [`elm.json`](./elm.json)
- [X] Run `npm run lint:format` to make sure code passes **elm-format**
- [X] Run `npm run lint:review` to make sure code passes **elm-review**
- [X] Run `npm run test:docs` to make sure code examples pass

## Publishing

- [X] Bump the version in [`elm.json`](./elm.json)
- [X] Add and commit those changes
- [X] Create a Git tag for the new version and push it
