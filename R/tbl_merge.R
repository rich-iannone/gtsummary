#' Merge two or more gtsummary objects
#'
#' Merges two or more `tbl_regression`, `tbl_uvregression`, `tbl_stack`,
#' `tbl_summary`, or `tbl_svysummary` objects and adds appropriate spanning headers.
#'
#' @param tbls List of gtsummary objects to merge
#' @param tab_spanner Character vector specifying the spanning headers.
#' Must be the same length as `tbls`. The
#' strings are interpreted with `gt::md`.
#' Must be same length as `tbls` argument
#' @family tbl_regression tools
#' @family tbl_uvregression tools
#' @family tbl_summary tools
#' @family tbl_survfit tools
#' @family tbl_svysummary tools
#' @seealso [tbl_stack]
#' @author Daniel D. Sjoberg
#' @export
#' @return A `tbl_merge` object
#' @examples
#' # Example 1 ----------------------------------
#' # Side-by-side Regression Models
#' library(survival)
#' t1 <-
#'   glm(response ~ trt + grade + age, trial, family = binomial) %>%
#'   tbl_regression(exponentiate = TRUE)
#' t2 <-
#'   coxph(Surv(ttdeath, death) ~ trt + grade + age, trial) %>%
#'   tbl_regression(exponentiate = TRUE)
#' tbl_merge_ex1 <-
#'   tbl_merge(
#'     tbls = list(t1, t2),
#'     tab_spanner = c("**Tumor Response**", "**Time to Death**")
#'   )
#'
#' # Example 2 ----------------------------------
#' # Descriptive statistics alongside univariate regression, with no spanning header
#' t3 <-
#'   trial[c("age", "grade", "response")] %>%
#'   tbl_summary(missing = "no") %>%
#'   add_n %>%
#'   modify_header(stat_0 ~ "**Summary Statistics**")
#' t4 <-
#'   tbl_uvregression(
#'     trial[c("ttdeath", "death", "age", "grade", "response")],
#'     method = coxph,
#'     y = Surv(ttdeath, death),
#'     exponentiate = TRUE,
#'     hide_n = TRUE
#'   )
#'
#' tbl_merge_ex2 <-
#'   tbl_merge(tbls = list(t3, t4)) %>%
#'   modify_spanning_header(everything() ~ NA_character_)
#'
#' @section Example Output:
#' \if{html}{Example 1}
#'
#' \if{html}{\figure{tbl_merge_ex1.png}{options: width=70\%}}
#'
#' \if{html}{Example 2}
#'
#' \if{html}{\figure{tbl_merge_ex2.png}{options: width=65\%}}
#'
tbl_merge <- function(tbls, tab_spanner = NULL) {
  # input checks ---------------------------------------------------------------
  # class of tbls
  if (!inherits(tbls, "list")) {
    stop("Expecting 'tbls' to be a list, e.g. 'tbls = list(tbl1, tbl2)'")
  }

  # checking all inputs are class gtsummary
  if (!purrr::every(tbls, ~inherits(.x, "gtsummary"))) {
    stop("All objects in 'tbls' must be class 'gtsummary'", call. = FALSE)
  }

  # at least two objects must be passed
  tbls_length <- length(tbls)
  if (tbls_length < 2) stop("Supply 2 or more gtsummary regression objects to 'tbls ='")

  # if tab spanner is null, default is Table 1, Table 2, etc....
  if (is.null(tab_spanner)) {
    tab_spanner <- paste0(c("**Table "), seq_len(length(tbls)), "**")
  }

  # length of spanning header matches number of models passed
  if (tbls_length != length(tab_spanner)) {
    stop("'tbls' and 'tab_spanner' must be the same length")
  }

  # adding tab_spanners
  tbls <-
    map2(
      tbls, seq_along(tbls),
      ~modify_spanning_header(
        .x, vars(everything(),
                 -any_of(c("variable", "row_type", "var_label", "label"))) ~ tab_spanner[.y])
    )


  # merging tables -------------------------------------------------------------
  # nesting data by variable (one line per variable), and renaming columns with number suffix
  nested_table <- map2(
    tbls, seq_along(tbls),
    function(x, y) {
      # creating a column that is the variable label
      group_by(x$table_body, .data$variable) %>%
        mutate(
          var_label = ifelse(.data$row_type == "label", .data$label, NA)
        ) %>%
        tidyr::fill(.data$var_label, .direction = "downup") %>%
        ungroup() %>%
        rename_at(
          vars(-c("variable", "row_type", "var_label", "label")),
          ~ glue("{.}_{y}")
        )
    })

  # checking that merging rows are unique --------------------------------------
  nested_table %>%
    purrr::some(
      ~nrow(.x) !=
        select(.x, all_of(c("variable", "row_type", "var_label", "label"))) %>% distinct() %>% nrow()
    ) %>%
    switch(
      paste("The merging columns (variable name, variable label, row type, and label column)",
            "are not unique and the merge may fail or result in a malformed table.",
            "If you previously 'tbl_stack'ed your tables, then 'tbl_merge'ing",
            "before you 'tbl_stack' may resolve the issue.") %>%
        stringr::str_wrap() %>%
        inform()
    )

  # nesting results within variable
  nested_table <- map(
    nested_table,
    ~ nest(.x, data = -any_of(c("variable", "var_label")))
  )

  # merging formatted objects together
  merged_table <-
    nested_table[[1]] %>%
    rename(table = .data$data)

  # cycling through all tbls, merging results into a column tibble
  for (i in 2:tbls_length) {
    merged_table <-
      merged_table %>%
      full_join(
        nested_table[[i]],
        by = c("variable", "var_label")
      ) %>%
      mutate(
        table = map2(
          .data$table, .data$data,
          function(table, data) {
            if (is.null(table)) {
              return(data)
            }
            if (is.null(data)) {
              return(table)
            }
            full_join(table, data, by = c("row_type", "label"))
          }
        )
      ) %>%
      select(-c("data", "table"), "table")
  }

  # unnesting results from within variable column tibbles
  table_body <-
    merged_table %>%
    unnest("table") %>%
    select(.data$variable, .data$var_label, .data$row_type, .data$label, everything())

  # renaming columns in stylings and updating ----------------------------------
  x <- .create_gtsummary_object(table_body = table_body,
                                tbls = tbls,
                                call_list = list(tbl_merge = match.call()))

  x <- .tbl_merge_update_table_styling(x, tbls)

  # returning results
  class(x) <- c("tbl_merge", class(x))
  x
}

.tbl_merge_update_table_styling <- function(x, tbls) {
  # update table_styling$header
  x$table_styling$header <-
    map2(
      tbls, seq_along(tbls),
      ~.x$table_styling$header %>%
        filter(!(.data$column %in% c("label", "variable", "var_label", "row_type") & .y != 1)) %>%
        mutate(
          column = ifelse(
            .data$column %in% c("label", "variable", "var_label", "row_type") & .y == 1,
            .data$column,
            paste0(.data$column, "_", .y)
          )
        )
    ) %>%
    purrr::reduce(dplyr::rows_update, by = "column", .init = x$table_styling$header)

  for (style_type in c("footnote", "footnote_abbrev", "fmt_fun", "text_format", "fmt_missing", "cols_merge")) {
    x$table_styling[[style_type]] <-
      map_dfr(
        seq_along(tbls),
        function(i) {
          style_updated <- tbls[[i]]$table_styling[[style_type]]

          # return if there are no rows
          if (!is.data.frame(style_updated) || nrow(style_updated) == 0)
            return(style_updated)

          # renaming column variable
          style_updated$column <-
            ifelse(
              style_updated$column %in% c("label", "variable", "var_label", "row_type") & i == 1,
              style_updated$column,
              paste0(style_updated$column, "_", i)
            ) %>%
            as.character()

          # updating column names in rows expr/quo
          if ("rows" %in% names(style_updated)) {
            style_updated$rows <-
              map(
                style_updated$rows,
                ~.rename_variables_in_expression(.x, i, tbls[[i]])
              )
          }

          # updating column names in pattern string
          if ("pattern" %in% names(style_updated)) {
            style_updated$pattern <-
              map_chr(
                style_updated$pattern,
                ~.rename_variables_in_pattern(.x, i, tbls[[i]])
              )
          }



          # style_updated <-
          #   tbls[[i]]$table_styling[[style_type]] %>%
          #   filter(!(.data$column %in% c("label", "variable", "var_label", "row_type") & i != 1)) %>%
          #   rowwise() %>%
          #   mutate(
          #     rows =
          #       switch(nrow(.) == 0, list()) %||%
          #       .rename_variables_in_expression(.data$rows, i, tbls[[i]]) %>% list(),
          #     column = ifelse(
          #       .data$column %in% c("label", "variable", "var_label", "row_type") & i == 1,
          #       .data$column,
          #       paste0(.data$column, "_", i)
          #     ) %>%
          #       as.character()
          #   ) %>%
          #   ungroup()

          # if ("pattern" %in% names(style_updated)) {
          #   style_updated$pattern <-
          #     .rename_variables_in_pattern(style_updated$pattern, i, tbls[[i]])
          # }
          style_updated
        }
      )
  }

  # take the first non-NULL element from tbls[[.]]
  for (style_type in c("caption", "source_note")) {
    x$table_styling[[style_type]] <-
      map(seq_along(tbls), ~pluck(tbls, .x, "table_styling", style_type)) %>%
      purrr::reduce(.f = `%||%`)
  }

  # # rename variables in expressions, and take first non-NULL element
  for (style_type in "horizontal_line_above") {
    x$table_styling[[style_type]] <-
      map(
        seq_along(tbls),
        ~.rename_variables_in_expression(
          rows = pluck(tbls, .x, "table_styling", style_type),
          id = .x,
          tbl = tbls[[.x]])
      )%>%
      purrr::reduce(.f = `%||%`)
  }

  x
}

.rename_variables_in_expression <- function(rows, id, tbl) {
  # if NULL, return rows expression unmodified
  rows_evaluated <- rlang::eval_tidy(rows, data = tbl$table_body)
  if (is.null(rows_evaluated)) return(rows)

  # convert rows to proper expression
  expr <- switch(inherits(rows, "quosure"), rlang::f_rhs(rows)) %||% rows

  # get all variable names in expression to be renamed
  columns <- tbl$table_styling$header$column
  var_list <-
    expr(~!!expr) %>% eval() %>% all.vars() %>%
    setdiff(c("label", "variable", "var_label", "row_type")) %>%
    intersect(columns)

  # if no variables to rename, return rows unaltered
  if (identical(var_list, character())) return(rows)

  # creating arguments list for `substitute()`
  substitute_args <- paste0(var_list, "_", id) %>% map(~expr(as.name(!!.x))) %>% set_names(var_list)

  # renaming columns in expression
  expr_renamed <- expr(do.call("substitute", list(expr, list(!!!substitute_args)))) %>% eval()

  # if original rows was a quosure, convert it back to one
  if (inherits(rows, "quosure")) {
    expr_renamed <-
      rlang::quo(!!expr_renamed) %>% structure(.Environment = attr(rows, ".Environment"))
  }

  expr_renamed
}

.rename_variables_in_pattern <- function(pattern, id, tbl) {
  # get all variable names in expression to be renamed
  columns <- tbl$table_styling$header$column
  var_list <-
    stringr::str_extract_all(pattern, "\\{.*?\\}") %>%
    map(stringr::str_remove_all, pattern = fixed("}")) %>%
    map(stringr::str_remove_all, pattern = fixed("{")) %>%
    unlist() %>%
    setdiff(c("label", "variable", "var_label", "row_type")) %>%
    intersect(columns)

  # if no variables to rename, return rows unaltered
  if (identical(var_list, character())) return(pattern)

  # replace variables with new names in pattern string.
  for (v in var_list) {
    pattern <-
      stringr::str_replace_all(
        string = pattern,
        pattern = fixed(paste0("{", v, "}")),
        replacement = fixed(paste0("{", v, "_", id, "}"))
      )
  }

  pattern
}

