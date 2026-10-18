# Sphinx configuration of the HITS manual (docs/). The pages are Markdown (MyST),
# readable as they are on GitHub; CI builds them into the HTML published at
# nipscern.com/library/hits.
#   python -m pip install -r docs/requirements.txt
#   python -m sphinx -W -b html docs docs/_build/html
# The version comes from the VERSION file at the root of the repository, the same
# file the release workflow checks against the tag.

import os

here = os.path.dirname(os.path.abspath(__file__))
with open(os.path.join(here, '..', 'VERSION'), encoding='utf-8') as f:
    release = f.read().strip()
version = release

project = 'HITS'
author = 'NIPS-CERN'
copyright = 'NIPS-CERN, Universidade Federal de Juiz de Fora'

extensions = ['myst_parser']
myst_enable_extensions = ['substitution']
myst_substitutions = {'release': release}   # {{ release }} in a page is the version
source_suffix = {'.md': 'markdown'}
root_doc = 'index'
exclude_patterns = ['_build']

myst_heading_anchors = 3          # [text](page.md#a-heading) links work as on GitHub

html_theme = 'furo'
html_title = f'HITS {release}'
html_static_path = []
