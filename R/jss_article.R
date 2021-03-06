#' Journal of Statistical Software (JSS) format.
#'
#' Format for creating a Journal of Statistical Software (JSS) articles. Adapted
#' from \url{https://www.jstatsoft.org/about/submissions}.
#' @inheritParams rmarkdown::pdf_document
#' @param ... Arguments to \code{rmarkdown::pdf_document}
#' @export
jss_article <- function(
  ..., keep_tex = TRUE, citation_package = 'natbib',
  pandoc_args = NULL
) {

  rmarkdown::pandoc_available('2.2', TRUE)

  pandoc_args <- c(
    pandoc_args,
    "--lua-filter", pkg_file("rmarkdown", "lua", "short-title.lua")
  )

  base <- pdf_document_format(
    "jss", keep_tex = keep_tex, citation_package = citation_package,
    pandoc_args = pandoc_args, ...
  )

  # Mostly copied from knitr::render_sweave
  base$knitr$opts_knit$out.format <- "sweave"

  base$knitr$opts_chunk <- merge_list(base$knitr$opts_chunk, list(
    prompt = TRUE, comment = NA, highlight = FALSE, tidy = FALSE,
    dev.args = list(pointsize = 11), fig.align = "center",
    R.options = list(prompt = 'R> ', continue = '+ '),
    fig.width = 4.9,  # 6.125" * 0.8, as in template
    fig.height = 3.675  # 4.9 * 3:4
  ))

  base$pandoc$ext <- '.tex'
  post <- base$post_processor
  # a hack for https://github.com/rstudio/rticles/issues/100 to add \AND to the author list
  base$post_processor <- function(metadata, input, output, clean, verbose) {
    if (is.function(post)) output = post(metadata, input, output, clean, verbose)
    f <- xfun::with_ext(output, '.tex')
    x <- xfun::read_utf8(f)
    x <- gsub('(\\\\AND )\\\\And ', '\\1', x)
    x <- gsub(' \\\\AND(\\\\\\\\)$', '\\1', x)
    xfun::write_utf8(x, f)
    tinytex::latexmk(
      f, base$pandoc$latex_engine,
      if ('--biblatex' %in% base$pandoc$args) 'biber' else 'bibtex'
    )
  }

  set_sweave_hooks(base, c('CodeInput', 'CodeOutput', 'CodeChunk'))
}

# wrap the content in a raw latex block
latex_block <- function(x, options, hook) {
  force(hook)
  function(x, options) {
    x2 <- hook(x, options)
    if (identical(x, x2)) x else paste0('```{=latex}\n', x2, '\n```')
  }
}

# use knitr's sweave hooks, but wrap chunk output in raw latex blocks
set_sweave_hooks <- function(base, ...) {
  hooks <- knitr::hooks_sweave(...)
  hooks[['chunk']] <- latex_block(x, options, hooks[['chunk']])
  base$knitr$knit_hooks <- merge_list(base$knitr$knit_hooks, hooks)
  base
}
