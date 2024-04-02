ifeq '$(findstring ;,$(PATH))' ';'
    UNAME := Windows
else
    UNAME := $(shell uname 2>/dev/null || echo Unknown)
    UNAME := $(patsubst CYGWIN%,Cygwin,$(UNAME))
    UNAME := $(patsubst MSYS%,MSYS,$(UNAME))
    UNAME := $(patsubst MINGW%,MSYS,$(UNAME))
endif

CONTENTDIR := content
BUILDDIR := build
FILES := $(wildcard $(CONTENTDIR)/*.md)

url ?= https://www.zotero.org/styles/ieee

define ZIP
	$(eval $@_LOCATION = $(1))
	$(eval $@_ZIP_FILE = $(2))
	$(eval $@_CONTENTS = $(3))

	$(eval $@_WINDOWS_ZIP = pwsh -Command (Compress-Archive -Force -Path $($@_CONTENTS) -DestinationPath $($@_ZIP_FILE)))

	$(eval $@_ZIP = zip -r $($@_ZIP_FILE) $($@_CONTENTS))

	cd $($@_LOCATION);                                                        \
		$(if $(findstring $(UNAME),Windows),$($@_WINDOWS_ZIP),$($@_ZIP))
endef

define MKDIR
	$(eval $@_DIRECTORY = $(1))

	$(eval $@_WINDOWS_MKDIR = pwsh -Command md $($@_DIRECTORY) -ea 0)

	$(eval $@_MKDIR = mkdir -p $($@_DIRECTORY))

	$(if $(findstring $(UNAME),Windows),$($@_WINDOWS_MKDIR),$($@_MKDIR))
endef

define CP
	$(eval $@_SOURCE = $(1))
	$(eval $@_DESTINATION = $(2))

	$(eval $@_WINDOWS_CP = XCOPY /E $($@_SOURCE) $($@_DESTINATION))

	$(eval $@_CP = cp -r $($@_SOURCE) $($@_DESTINATION))

	$(if $(findstring $(UNAME),Windows),$($@_WINDOWS_CP),$($@_CP))
endef

define RM
	$(eval $@_DIR = $(1))

	$(eval $@_WINDOWS_RM = RMDIR /S /Q $($@_DIR))

	$(eval $@_RM = rm -rf $($@_DIR))

	$(if $(findstring $(UNAME),Windows),$($@_WINDOWS_RM),$($@_RM))
endef

citation-style.csl:
	$(error File `citation_style.csl` was not found!\
	Use `make download_csl url=$$(url)` to download it)

download_csl:
	@curl -o citation-style.csl $(url)

%.tex: citation-style.csl
	@echo Generating latex...;                                                \
	$(call MKDIR,$(BUILDDIR)/content);                                        \
	pandoc $(FILES)                                                           \
		--metadata-file=$(CONTENTDIR)/metadata.yml                            \
		--resource-path=$(CONTENTDIR)/images/                                 \
		--from=markdown                                                       \
		--bibliography=$(CONTENTDIR)/bibliography.bib                         \
		--csl=citation-style.csl                                              \
		--filter=pandoc-crossref                                              \
		--natbib                                                              \
		--template=templates/template.latex                                   \
		--pdf-engine=pdflatex                                                 \
		--to=latex                                                            \
		--output=$@;                                                          \
	$(call CP,$(CONTENTDIR)/bibliography.bib,$(BUILDDIR)/content);            \
	$(call CP,$(CONTENTDIR)/images,$(BUILDDIR)/content);                      \
	echo Generated $@

%.pdf: $(BUILDDIR)/%.tex
	@echo Generating PDF...;                                                  \
	cd $(BUILDDIR);                                                           \
		pdflatex --interaction=batchmode paper;                               \
		bibtex paper;                                                         \
		pdflatex --interaction=batchmode paper;                               \
		pdflatex --interaction=batchmode paper;                               \
	echo Generated $(BUILDDIR)/$@

.PHONY: $(BUILDDIR)/ publish clean citation_style.csl

$(BUILDDIR)/: paper.pdf

publish: $(BUILDDIR)/$(wildcard *.pdf)
	@$(call ZIP,$(BUILDDIR),paper.zip,./*.bbl ./*.tex content/images/*.pdf content/images/*.png content/images/*.jpg)

clean:
	@$(call RM,$(BUILDDIR))
