% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/add_p.R
\name{add_p.tbl_svysummary}
\alias{add_p.tbl_svysummary}
\title{Adds p-values to svysummary tables}
\usage{
\method{add_p}{tbl_svysummary}(
  x,
  test = NULL,
  pvalue_fun = NULL,
  include = everything(),
  test.args = NULL,
  ...
)
}
\arguments{
\item{x}{Object with class \code{tbl_svysummary} from the \link{tbl_svysummary} function}

\item{test}{List of formulas specifying statistical tests to perform,
e.g. \code{list(all_continuous() ~ "svy.t.test", all_categorical() ~ "svy.wald.test")}.
Options include
\itemize{
\item \code{"svy.t.test"} for a t-test adapted to complex survey samples (cf. \code{survey::svyttest}),
\item \code{"svy.wilcox.test"} for a Wilcoxon rank-sum test for complex survey samples (cf. \code{survey::svyranktest}),
\item \code{"svy.kruskal.test"} for a Kruskal-Wallis rank-sum test for complex survey samples (cf. \code{survey::svyranktest}),
\item \code{"svy.vanderwaerden.test"} for a van der Waerden's normal-scores test for complex survey samples (cf. \code{survey::svyranktest}),
\item \code{"svy.median.test"} for a Mood's test for the median for complex survey samples (cf. \code{survey::svyranktest}),
\item \code{"svy.chisq.test"} for a Chi-squared test with Rao & Scott's second-order correction (cf. \code{survey::svychisq}),
\item \code{"svy.adj.chisq.test"} for a Chi-squared test adjusted by a design effect estimate (cf. \code{survey::svychisq}),
\item \code{"svy.wald.test"} for a Wald test of independence for complex survey samples (cf. \code{survey::svychisq}),
\item \code{"svy.adj.wald.test"} for an adjusted Wald test of independence for complex survey samples (cf. \code{survey::svychisq}),
\item \code{"svy.lincom.test"} for a test of independence using the exact asymptotic distribution for complex survey samples (cf. \code{survey::svychisq}),
\item \code{"svy.saddlepoint.test"} for a test of independence using a saddlepoint approximation for complex survey samples (cf. \code{survey::svychisq}),
}

Tests default to \code{"svy.wilcox.test"} for continuous variables and \code{"svy.chisq.test"}
for categorical variables.}

\item{pvalue_fun}{Function to round and format p-values.
Default is \link{style_pvalue}.
The function must have a numeric vector input (the numeric, exact p-value),
and return a string that is the rounded/formatted p-value (e.g.
\code{pvalue_fun = function(x) style_pvalue(x, digits = 2)} or equivalently,
\code{purrr::partial(style_pvalue, digits = 2)}).}

\item{include}{Variables to include in output. Input may be a vector of
quoted variable names, unquoted variable names, or tidyselect select helper
functions. Default is \code{everything()}.}

\item{test.args}{List of formulas containing additional arguments to pass to
tests that accept arguments. For example, add an argument for all t-tests,
use \code{test.args = all_tests("t.test") ~ list(var.equal = TRUE)}}

\item{...}{Not used}
}
\value{
A \code{tbl_svysummary} object
}
\description{
\lifecycle{experimental}
Adds p-values to tables created by \code{tbl_svysummary} by comparing values across groups.
}
\section{Example Output}{

\if{html}{Example 1}

\if{html}{\figure{add_p_svysummary_ex1.png}{options: width=45\%}}

\if{html}{Example 2}

\if{html}{\figure{add_p_svysummary_ex2.png}{options: width=65\%}}

\if{html}{Example 3}

\if{html}{\figure{add_p_svysummary_ex3.png}{options: width=60\%}}
}

\examples{
# Example 1 ----------------------------------
# A simple weighted dataset
add_p_svysummary_ex1 <-
  survey::svydesign(~1, data = as.data.frame(Titanic), weights = ~Freq) \%>\%
  tbl_svysummary(by = Survived) \%>\%
  add_p()

# A dataset with a complex design
data(api, package = "survey")
d_clust <- survey::svydesign(id = ~dnum, weights = ~pw, data = apiclus1, fpc = ~fpc)

# Example 2 ----------------------------------
add_p_svysummary_ex2 <-
  tbl_svysummary(d_clust, by = both, include = c(cname, api00, api99, both)) \%>\%
  add_p()

# Example 3 ----------------------------------
# change tests to svy t-test and Wald test
add_p_svysummary_ex3 <-
  tbl_svysummary(d_clust, by = both, include = c(cname, api00, api99, both)) \%>\%
  add_p(
    test = list(all_continuous() ~ "svy.t.test",
                all_categorical() ~ "svy.wald.test")
  )
}
\seealso{
Other tbl_svysummary tools: 
\code{\link{add_n.tbl_summary}()},
\code{\link{add_overall}()},
\code{\link{add_q}()},
\code{\link{add_stat_label}()},
\code{\link{modify}},
\code{\link{tbl_merge}()},
\code{\link{tbl_stack}()},
\code{\link{tbl_svysummary}()}
}
\author{
Joseph Larmarange
}
\concept{tbl_svysummary tools}
