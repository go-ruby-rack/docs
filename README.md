<p align="center"><img src="https://raw.githubusercontent.com/go-ruby-rack/brand/main/social/go-ruby-rack.png" alt="go-ruby-rack/docs" width="720"></p>

# go-ruby-rack/docs

The documentation site for [go-ruby-rack](https://github.com/go-ruby-rack) —
a pure-Go (no cgo) reimplementation of the deterministic core of Ruby's Rack.
Built with [MkDocs Material](https://squidfunk.github.io/mkdocs-material/) and
versioned with [mike](https://github.com/jimporter/mike), served at
<https://go-ruby-rack.github.io/docs/>.

`.github/workflows/docs.yml` builds the site with mike and publishes it to the
`gh-pages` branch on every push to `main`; GitHub Pages serves that branch.

## Local preview

```bash
pip install -r requirements.txt
mkdocs serve      # http://127.0.0.1:8000
```

## License

BSD-3-Clause — see [LICENSE](LICENSE). Copyright the go-ruby-rack/docs authors.
