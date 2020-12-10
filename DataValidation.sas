/*Minimize content written to log for faster processing*/
options nonotes;
/*Create a 1,000 simulations of our dataset and fit a model to each simulation*/
%macro ValidateData;

/*Simulate 5,000 datasets for our model*/
%DO i=1 %to 5000;

  /*Create a Dataset called MixedData to simulate a table with several fixed effects and a random effect of Geography*/
  DATA MixedData;
	/*There are 'four realizations' of our random variable, Geopgrahy. Geography as a random effect explains variance by region.
	  Since we have 4 realziation, the 4 expected value of each estimates will sum to zero.  The purpose of the mixed model is it 
	  allows the model to generalize to generalize to other geographys not in our data.*/
      DO Geo='South','East','North','West';

        /*Random effects must be distributed with a mean of 0. The variance is not fixed, in this case we will set it equal to 5.*/
	    Geo_rand=rand('Normal',0,5);

        /*Simulate 20,000 observation, 5,000 for each geograph*/
        DO i=1 to 5000;
	      /*Define Fixed Effects and Epsilon. Since marketing campaigns are never 0, We are taxking a max value of our output or 0.
		    Additionally, create the corresponding log(var+1) values*/
          x1=max(rand('Normal',7.5,1.2),0);
		  ln_x1=log(x1+1);
          x2=max(rand('Normal',12.2,1.1),0);
		  ln_x2=log(x2+1);
          x3=max(rand('Normal',8.1,1.2),0);
		  ln_x3=log(x3+1);
          x4=max(rand('Normal',9.3,.9),0);
		  ln_x4=log(x4+1);
          x5=max(rand('Normal',10.5,1),0);
		  ln_x5=log(x5+1);
          Epsilon=rand('Normal',0,.05);

          /*Create y for each observation.  The value of y is also dependent on our variance factors*/
          y=10.7 + 0.15*x1 + 0.2*x2 + 0.05*x3 + 0.09*x4 + Epsilon + Geo_rand; 
		  ln_y=log(y+1);
	      Region=Geo;        
          output;
        END;

		/*Append our results into a single table*/
	  END;
    drop i;
  RUN;
  /*Minimize content written to results for faster processing*/
  ods select none;
  PROC MIXED data=MixedData nobound noclprint noinfo noitprint noprofile plots=none;
    class Geo;
    model ln_y= ln_x1 ln_x2 ln_x3 ln_x4 / s;
	random int / subject=geo;
	ods output SolutionF=SolutionF(keep=Effect Estimate);
  RUN;

  PROC TRANSPOSE data=SolutionF out=SolutionF_trans;
    id Effect;
    var Estimate;
  RUN;

  %IF &i=1 %then %do;
    DATA SolutionF_Aggregate;
      length _Name_ $11.;
      set SolutionF_trans(in=a);
      _NAME_='Model1';
    RUN;
  %END;

  %ELSE %DO;
    DATA SolutionF_Aggregate;
      length _Name_ $11.;
      set SolutionF_Aggregate SolutionF_trans(in=a);
      IF a then _NAME_='Model'||"&i.";
    RUN;
  %END;

  PROC DATASETS lib=work nodetails nolist nowarn;
    delete SolutionF SolutionF_trans;
  RUN;

%END;
%mend;

%ValidateData;

ods select all;
/*Find the 50th percentile for each parameter and check to match our model.  The intercept will vary due to the random effects*/
PROC MEANS DATA=SolutionF_Aggregate n mean median;
  var Intercept ln_x1 ln_x2 ln_x3 ln_x4;
RUN;
