#' Estimate Model
#'
#' todo: explain
#'
#' @param control_arr array of control group correlation matrices. either an array or data matrix form
#' @param diagnosed_arr array of diagnosed group correlation matrices. either an array or data matrix form
#' @param dim_alpha the number of columns in alpha. default 1
#' @param LinkFunc a list of function. must include func, inverse, rev_func and null_value. see \link[corrfuncs]{LinkFuncSkeleton}
#' @param model_reg_config see \link[corrfuncs]{configurations}. arguments passed will override the defaults.
#' @param matrix_reg_config see \link[corrfuncs]{configurations}. arguments passed will override the defaults.
#' @param iid_config list of two lists named 'iter_config' and 'optim_config', for the optimization of the model with identity matrix covariance matrix. see \link[corrfuncs]{configurations}. arguments passed will override the defaults.
#' @param cov_config list of two lists named 'iter_config' and 'optim_config', for the optimization of the model with a specified covariance matrix. see \link[corrfuncs]{configurations}. arguments passed will override the defaults.
#' @param raw_start if true, don't optimize with the identity matrix before optimizing with a specified covariance matrix
#' @param bias_correction if true, correct the estimates to the median: a' = a - med(a) + null_value
#' @param early_stop if true, stop the optimization of the joint loss function (of theta and alpha) didn't decrease in the last iteration.
#' @param verbose if true, print status to console
#' @return a list of the following:
#' @return - theta: a matrix, the estimates of theta
#' @return - alpha: a matrix, the estimates of alpha
#' @return - LinkFunc: the link function used same as the parameter LinkFunc
#' @return - regularization: the same as model_reg_config parameter
#' @return - vcov: the weighting matrix used in the optimization - the inverse of the correlations' covariance matrix
#' @return - convergence: a vector with the convergence in each iteration. see \link[stats]{optim}
#' @return - steps: the estimates of theta, alpha in each iteration
#' @return - log_optim: if optim_config$log_optim=TRUE, will return the output of \link[stats]{optim} for each iteration. else, NA.
#' @seealso \link[corrfuncs]{configurations}
#' @export
#'
estimate_model <- function(
  control_arr, diagnosed_arr, dim_alpha = 1,
  LinkFunc = LinkFunctions$multiplicative_identity,
  model_reg_config = list(), matrix_reg_config = list(),
  iid_config = list(), cov_config = list(),
  raw_start = FALSE, bias_correction = FALSE, early_stop = FALSE,
  verbose = TRUE)
{
  for(name in c('iter_config', 'optim_config')){
    if(!name %in% names(iid_config)) iid_config[[name]] <- list()
    if(!name %in% names(cov_config)) cov_config[[name]] <- list()
  }
  if(length(verbose) == 1) verbose <- rep(verbose, 2)

  control_datamatrix <- convert_corr_array_to_data_matrix(control_arr)
  diagnosed_datamatrix <- convert_corr_array_to_data_matrix(diagnosed_arr)

  alpha0 <- theta0 <- NULL
  if(!raw_start){
    iid_model <- optimiser(
      control_datamatrix = control_datamatrix, diagnosed_datamatrix = diagnosed_datamatrix,
      alpha0 = NULL, theta0 = NULL,
      weight_matrix = NULL, dim_alpha = dim_alpha, LinkFunc = LinkFunc,
      model_reg_config = model_reg_config, matrix_reg_config = matrix_reg_config,
      iter_config = iid_config$iter_config, optim_config = iid_config$optim_config,
      early_stop = early_stop, verbose = verbose[1]
    )
    alpha0 <- iid_model$alpha
    theta0 <- iid_model$theta
  }

  weight_matrix <- corrmat_covariance_from_datamatrix(diagnosed_datamatrix)

  cov_model <- optimiser(
    control_datamatrix = control_datamatrix, diagnosed_datamatrix = diagnosed_datamatrix,
    alpha0 = alpha0, theta0 = theta0,
    weight_matrix = weight_matrix, dim_alpha = dim_alpha, LinkFunc = LinkFunc,
    model_reg_config = model_reg_config, matrix_reg_config = matrix_reg_config,
    iter_config = cov_config$iter_config, optim_config = cov_config$optim_config,
    early_stop = early_stop, verbose = verbose[2]
  )

  if(bias_correction)
    cov_model$alpha <- cov_model$alpha - stats::median(cov_model$alpha) + LinkFunc$null_value

  return(cov_model)
}
