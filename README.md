# zvenc

Scheduler / Agenda CLI.

This is a personal project.  I do not provide any support for it.


## Usage

Build it:

```sh
zig build
```

Add it to your `.zshrc`:

```sh
# zvenc
export PATH=$PATH:"<this_project_path>/zig-out/bin"
alias zvenc="zvenc ~/.zvenc.db"
zvenc
```

Now you'll get reminders whenever you open a terminal:

![screenshot-terminal](images/screenshot-terminal.png)


TODO: Add docs on how to add scheduler rules and agenda entries.


## Notes

I've made this project to learn Zig and replace an old spreadsheet I've been using for "daily reminders" of
stuff I have to do.

This is eternally going to be a work-in-progress, but it's already at the stage where I replaced the spreadsheet,
so I'm happy with it.

As part of this process, I've extracted a few projects that could be used for other apps.  I do not provide support
to any of it, but they are all MIT license if you want to use or fork:

- [zsqlite-c](https://github.com/thiago-negri/zsqlite-c): Drop in dependency to add SQLite as a static library into
  a Zig project.
- [zsqlite](https://github.com/thiago-negri/zsqlite): Small library that "ziggifies" the SQLite API.
- [zsqlite-migrate](https://github.com/thiago-negri/zsqlite-migrate): Library that manages SQL migrations for a
  SQLite database.
- [zsqlite-minify](https://github.com/thiago-negri/zsqlite-minify): Library that minifies and embeds SQL files into
  a Zig executable.  Oriented towards SQLite syntax.

