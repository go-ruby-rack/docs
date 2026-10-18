<p align="center"><img src="https://raw.githubusercontent.com/go-ruby-rack/brand/main/social/go-ruby-rack.png" alt="go-ruby-rack/docs" width="720"></p>

# go-ruby-rack/docs

The documentation site for [go-ruby-rack](https://github.com/go-ruby-rack) —
a pure-Go (no cgo) reimplementation of the deterministic core of Ruby's Rack.
Built with [Hugo](https://gohugo.io/) and this fleet's [Hextra fork](https://github.com/tannevaled/hextra) — upstream Hextra plus the opt-in features the fleet's sites use, served at
<https://go-ruby-rack.github.io/docs/>.

`.github/workflows/docs.yml` builds the site with mike and publishes it to the
`gh-pages` branch on every push to `main`; GitHub Pages serves that branch.

## Local preview

```bash
git submodule update --init --recursive   # themes/hextra, pinned at a release tag
hugo server                               # http://localhost:1313
```

## License

BSD-3-Clause — see [LICENSE](LICENSE). Copyright the go-ruby-rack/docs authors.
