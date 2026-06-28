# Elixir Summer School

A small, real-time multiplayer game built with **Elixir** and the **Phoenix** web
framework. It was created as a hands-on learning exercise for the Elixir Summer
School at Polytechnic University of Bucharest, and assumes almost no prior Elixir
or functional-programming experience.

## What is this project?

Behind the scenes the project is a tour of the core ideas of what makes Elixir a fun and reliable language: pattern matching, immutable data, processes (a `GenServer` holding game state), real-time messaging with `Phoenix.PubSub`, and live UI with Phoenix LiveView.
reading the code is the point.

## Prerequisites

This project needs **Erlang** and **Elixir**. The versions used to build it are:

| Tool        | Version            |
| ----------- | ------------------ |
| Erlang/OTP  | 27                 |
| Elixir      | 1.19 or newer      |

### How to install them

The easiest and recommended way is the version manager **[asdf](https://asdf-vm.com/)**,
which installs the exact versions for you and keeps your machine clean.

**macOS / Linux**

```bash
# 1. Install asdf (see https://asdf-vm.com/guide/getting-started.html)
#    On macOS you can use Homebrew:
brew install asdf

# 2. Add the Erlang and Elixir plugins
asdf plugin add erlang
asdf plugin add elixir

# 3. Install the versions pinned in the project's .tool-versions file
#    (run this from inside the project folder)
asdf install
```

> On macOS, building Erlang needs a few system libraries. If `asdf install
> erlang` fails, follow the asdf-erlang notes:
> https://github.com/asdf-vm/asdf-erlang#before-asdf-install

**Prefer a direct install instead of asdf?**

- macOS (Homebrew): `brew install erlang elixir`
- Windows / Linux: follow the official guide at
  https://elixir-lang.org/install.html

### Check that it worked

```bash
elixir --version
```

You should see Elixir `1.19` (or newer) and Erlang/OTP `27`.

## Running the project

From inside the project folder:

```bash
# 1. Install dependencies and build front-end assets (run once)
mix setup

# 2. Start the server
mix phx.server
```

The first command may take a minute the first time, it downloads the Elixir
libraries and the CSS/JS tooling. When the server is running, open your browser
at:

 **http://localhost:4000**

To try the multiplayer part, open the same address in **several browser tabs or
windows** (each tab is a separate player), give each one a name, and click
*Ready* in all of them.

> Tip: you can also start the server inside an interactive Elixir shell with
> `iex -S mix phx.server`. This lets you inspect the running system while it
> works — very handy for learning.

To stop the server, press `Ctrl+C` twice in the terminal.

## The package

Each round the game generates a random **package**. Every package has these
attributes and possible values (defined in `lib/school/package.ex`):

```text
type:                letter | parcel | fragile
weight:              number (grams)
destination:         domestic | eu | international
shipping_class:      standard | express | priority
declared_value:      number (euros)
has_customs_form:    true | false
has_insurance:       true | false
has_fragile_sticker: true | false
```

## The validation rules

A package is **valid** only if it satisfies **every** rule that is currently
active. The game starts with a few active rules and activates more as time passes.
The full set of rules is:

1. Letters must weigh under 500g.
2. International packages require a customs form.
3. Fragile packages cannot use standard shipping.
4. Parcels over 5000g must use priority shipping.
5. Declared value over 100€ requires insurance.
6. Fragile packages must have a fragile sticker.
7. EU and international packages must use express or priority.
8. Letters cannot have insurance.
9. Standard shipping is only available for domestic packages under 2000g.
10. Fragile international packages over 1000g must use priority.

These rules live in `lib/school/logic.ex`.

## Working through the project

The git history is split into small, numbered checkpoints (look at
`git log --oneline`). Each commit adds one feature, a player lobby, score
broadcasting, the timer, the leaderboard etc..

## Learn more

- Elixir: https://elixir-lang.org/getting-started/introduction.html
- Phoenix framework: https://www.phoenixframework.org/
- Phoenix guides: https://hexdocs.pm/phoenix/overview.html
- Elixir forum: https://elixirforum.com/
