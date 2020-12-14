# Marketing Mix Modeling
## Introduction
Marketing Mix Modeling (MMM) is a statistical technique for measuring the mix of marketing campaigns that produce an optimal outcome, such as sales, revenue, or profit. More specifically, the end goal is to help businesses understand the <b>marginal</b> effect of their marketing campaigns. The standard approach is to apply linear regression, nonlinear regression, or ARIMA models to time series data. MMM as a practice should not be confused with mixed models, a statistical regression model for fitting fixed and random effects. The general flow for MMM is the following:
<ul>
  <li>Data collection</li>
  <li>Exploratory Data Analysis such as checking for outliers, missing data, correlations, and general correctness of data</li>
  <li>Deriving new independent variables</li> 
  <li>Transforming input variables such as applying lags, log, and advertising adstock. The lags provide the time element.  The advertising adstock provides the rate of decay of a marketing campaign.  That is, marketing campaigns distribute their effects over different periods of time.</li>
  <li>Fit linear mixed models to estimate and measure the impact of marketing campaigns.</li>
  <li>Perform variable selection and minimize multicollinearity</li>
  <li>Find the optimal mix of input parameters for the selected model</li>
  <li>Receiving feedback from the business</li>
</ul>

Dependent variables are usually represented by unit sales or revenue, or some other industry specific metric. Examples of independent variables, depending on the industry, include:
<ul>
  <li>TV ads</li>
  <li>Radio ads</li>
  <li>In person events</li>
  <li>Pharmaceutical samples and details</li>
  <li>Print</li>
  <li>Online clicks</li>
  <li>Affiliate marketing</li>
  <li>Mail</li>
  <li>Email</li>
</ul>

## Technical Details
### Model Techniques
There are many different ways to develop statistical models to solve MMM problems. This repository will demonstrate a multiplicative model, also known as log-log models. Other models include:
<ul><li>Linear Models</li>
  <li>Log-Linear Models</li>
  <li>Linear-Log Models</li>
  <li>Additive Models</li>
  <li>Power Series Model</li>
  <li>Autoregressive Time Series Models</li>
</ul>

### Multiplicative Models

A linear mixed model is used to estimate the effect of each campaign, <i>X<sub>N</sub></i> has on our outcome, <i>y</i>.  A linear mixed model is defined as:
<p align="center">
<img src='https://render.githubusercontent.com/render/math?math=y=X{\beta}%20%2bZ{\mu}%20%2b%20{\epsilon}'>
</p>
<p align="center">
Where:<br>
<i>y</i> is a vector of known values.<br>
<i>β</i> is a vector of fixed effects to be estimated<br>
<i>μ</i> is a vector of random effects to be estimated<br>
X and Z are the fixed and random design matricies respectively
</p>
<br>
The multiplicativity of the model comes from the data preprocessing before fitting the model. A natural log transformation is applied to the dependent variable <i>y</i> and each independent variable <i>X<sub>N</sub></i> such that the new dependent variable is <i>ln(y+1)</i>, and the independent variables are <i>ln(X<sub>N</sub>+1)</i>. One is added to each term since there is no mapping for <i>ln(0) -> ℝ</i>. Campaign values cannot be less than zero.

Our formula now takes the following form:
<p align="center">
<img src='https://render.githubusercontent.com/render/math?math=ln(y %2b 1)= {\beta_0} %2b {\beta_1}(X_1 %2b +1) %2b {\beta_2}(X_2 %2b +1)%2b...%2b{\beta_n}(X_n %2b +1) %2b Z_1*Random_1 %2b...%2b Z_n*Random_n'>
</p>

Next, exponentiate both sides:
<p align='center'>
<img src="https://render.githubusercontent.com/render/math?math=y%20%2b%201={e^{\beta_0}}*{(x_1%20%2b%201)}^{\beta_1}*{(x_2%20%2b%201)}^{\beta_2}*...*{(x_n%20%2b%201)}^{\beta_n}*{e^{{Z_1}*Random_1}}*...*{e^{{Z_n}*Random_n}}" />
</p>

It's clear how we have a multiplicative model.  A multiplicative model has several advantages:
<ul>
  <li>The model coefficients are interpreted as elasticities</li>
  <li>The model has a stabilizing variance effect</li>
  <li>The multiplicativity of the model provides interaction effects between independent variables</li>
  <li>The exponential structure models diminishing returns and models tradeoff efficiently</li>
 </ul>

### Other Considerations
<ul>
  <li><b>Multicollinearity</b>: A variable may be correlated with a linear combination of other input variables are correlated. Independent variables that correlated can lead to incorrect parameter estimates and not represent a marketing campaign's actual effect on an outcome. Therefore, we must measure for multicollinearity in our process.  We will use VIF scores to see if two variables are correlated; however, there are other ways to measure multicollinearity.</li> 
  <li><b>Optimization Preparation</b>: The end goal is to run our final model through an optimization algorithm to understand what is the best mix of marketing campaign to spend dollars. For the optimization algorightm to understand the tradeoff between two campaigns, it must have a common unit between the two so that it can measure trade offs.  That is, you must have the dollar cost per marginal unit.  This will be vital to collect before you analyze so you can meet your end goal. </li>
</ul>

### Best Practices
There are several best practices to be considered when fitting MMM models.  They include, but are not limited to:
<ul> <li>MMM should consist of a minimum of two years of data. Less than two years of data make it near impossible to measure seasonal effects in our data. Seasonal effects can add noise to our model and ultimately lead to incorrect parameter estimates. An example of a seasonal effect would be how Valentine's day drives valentine's cards' revenue.</li>
  <li>Data should be provided at the level at which businesses make decisions. Examples include providing the appropriate geography/region that campaigns applied to and having data at the time level, such as weekly, monthly, or quarterly.  A moving average can help breakdown time to a finer level, </li>  
  <li>If there are missing values, then they should be changed to 0.  In most cases, a missing value implies there was $0 spend that time period, and the missing values was brought in from a join.
  <li>Lastly, the values of independent variables should fall within the range that the model was fit on.  Any ranges outside of these are extrapolating and invalidate the model.</li></ul>

## Code Flow
The following code is written in SAS. The files are placed in the order they should run.  The files and their descriptions include:
<ul>
  <li>
    <b>DataGeneration.sas</b>: This code will simulate data for our analysis.  DataGeneration.sas will use a data step to map the relationships between the dependent variable, independent variables, and random effects using a regression formula. To varify our fixed effects match, you will need to run a bootstrap across several samples.
  </li>
  <li>
    <b>AdStock.sas</b>: A specific campaign is likely to distribute its effects and awareness of multiple time periods. That is, campaigns don't have their full effect for a specific time period, they decay over multipe time periods.  Therefore, we will apply a 'retention rate' to each variable and carry over some of the effect to the next period.  That is The model will select the best variable and surface the true decay rate of a variable.  In the code, a nine different levels of retention rate are added.  I have included Adstock.xslx in this repo for you to play around and understand the concept.
  </li>
  <li>
    <b>lag.sas</b>: While adstock measures how a campaign decays over time, lags measure when the campain begins to have its effectiveness.  Lag.sas adds a lag value to each input value.  The user specifies the relevant predictors, and the code will add N number of lags where N is user specified.
  </li>  
    
    
    
    
</ul>

## To Do
<ol>
  <li>Fix the simulation of the random effects for a multiplicative model</li>
  <li>I show how to do adstock and lag analysis, but I did not build them in as signifigacnt variables.  I will adjust the model accordingly at a later time</li>
</ol>
  

<!--(  
In this example we will build non-linear mixed models. 
Optimization requires a conversion amount
Minimum 2 years data.  Granular data any level – role up to the business decision and geography.  Some may have to role down such as moving average etc.  If no needs to be 0.
-->
Notes
Base sales
non-linear variables
Variable creatation data cleanup
adstock analysis
model build
multicollineraity check
Optimization
Non-linear model -elasticity
Inferentials Statics

Model is built many many many times, final model is picked based on a number of factors
#Future STeps - could rsubmit for faster results.


</ul>


