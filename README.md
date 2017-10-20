# fzftools

fzftools is an organized collection of [FZF](https://github.com/junegunn/fzf)
scripts with a consistent interface.

## Installation

If you use bash:

```console
$ git clone https://github.com/midchildan/fzftools.git
$ echo source "$(pwd)/fzftools.bash" >> ~/.bashrc
```
Or, if you use zsh:

```console
$ git clone https://github.com/midchildan/fzftools.git
$ echo source "$(pwd)/fzftools.zsh" >> ~/.zshrc
```

## Examples

### Filter a list of directories

```console
$ fzf-sel dir
```

### Filter a list of git commits

```console
$ fzf-sel git commit
```

### cd to a subdirectory

```console
$ fzf-run cd dir
```

### Install some formula with Homebrew

```console
$ fzf-run brew install formula
```

### Edit a git file

```console
$ fzf-run vim "git file"
```

You can also pass additional arguments:

```console
$ fzf-run vim "git file" --remote-tab-silent
```

### Interactive rebase with git

```console
$ fzf-run git rebase commit -i
```

### Browse git commits

```console
$ fzf-loop git show commit
```

## Usage

fzftools provides two commands: fzf-sel and fzf-run.

### fzf-sel

```
Usage: fzf-sel selector
```

Filters list of items associated with `selector` using FZF. The list of
available selectors are:

- dir
- dirstack
- file
- fc
- process
- brew formula
- brew installed
- brew leaves
- git branch
- git commit
- git file
- git remote
- git stash
- git status
- git tag

### fzf-run

```
Usage: fzf-run command [subcommands...] selector [flags...]
```

Runs `command` with the output of `fzf-sel selector` as its arguments.

### fzf-loop

```
Usage: fzf-loop command [subcommands...] selector [flags...]
```

Reapetedly run `fzf-run` until selection is canceled.

## Customization

You can add a custom `selector` by defining `fzf::sel::$(selector)` as a
function. You can also customize the behavior of `fzf-run command` by defining 
`fzf::run::$(command)` as a function.

## License

See [LICENSE](LICENSE).
