/*******************************************************************\
 This code runs runs through the all the model combinations created
 in 'ModelCominbations.sas' code. It takes several model metrics including:
 -AIC
 -VIF
 -Positive Variable Count
 -MAPE

 The code puts all the model metrics into a dataset called 
 model_metrics. The analyst can use these metrics to determine what
 model best suits their needs .

 Warning: Make sure you are tracking and managing your modelcomb and
 and model metrics datasets so models are not getting mixed up.
\*******************************************************************/

/*Turns off listing for faster run time*/
ods listing close; 
/*Turns off html for faster run time*/
ods html close;    
/*Turns off the results window for faster run time*/
ods results off;   

/*Turn off the graphics*/
ods graphics off;
/*Turns off the log except for the first 10 errors/warnings for faster run time*/
options nosource nosource2 nonotes errors=10; 

/*Put the start time to see how long the program runs*/
%let datetime_start = %sysfunc(TIME()) ;          

%macro mixmodel;

  /*Delete old model  metrics*/
  PROC DATASETS lib=work nodetails nolist nowarn;
    delete model_metrics;                            
  QUIT;
  
  /*Run a DO loop to go through every model combination.  This needs the &modelcount
    macro from the previous code, ModelComninations.sas*/
  %DO i=1 %to &modelcount;
    %put Running Iteration &i;
    /*Call the dataset with the model combinations*/
    DATA _NULL_;
       set modelcomb;
	   /*Set the row with the ith model combination*/
	   where key=&i;
       /*Load the ith iteration of the model into a macro*/
       call symputx ('model_stmt',var,'G');
	   /*Load the key of the ith iteration of the model into a macro*/
	   call symputx('key',key,'G');
    RUN;

    /*The next step is to run PROC MIXED.  There are two different 
	  methodologies that can be used:
	  1) Model all the inputs with GEO as a random effect.  This is
	    the first PROC MIXED method listed and is commented out
	  2) Model all the inputs with GEO, Inputs, and the Intercept, 
	     as a random effect.
	  In general I try model methodology 1, and if that doesn't 
	  produce desirable models, I move to methodology 2.

     /*Methodology 1*//*
     PROC MIXED data=Mixed_Data_ADSTOCK_log noinfo noitprint noclprint;
       ods output SolutionF= _betas_fixed_geo;
       ods output FitStatistics=AIC;
       ods output SolutionR=R;
       class geo;
       model y= &model_stmt / solution outp=_pred_1;
       random geo/ solution;
     RUN;*/

     /*Methdology 2*/
	 /*Call Proc MIXED and surpress output for fast processing*/
	
     PROC MIXED data=Mixed_Data_ADSTOCK_log noinfo noitprint noclprint ;
       /*Output the parameter estimates to a dataset called
	     _betas_fixed_geo*/
       ods output SolutionF= _betas_fixed_geo;
	   /*Output the AIC metric to a dataset called AIC*/
       ods output FitStatistics=AIC;
	   /*Specify that geo is a nominal variable*/
       class geo;
	   /*The model statement declares the independent variable,
	     and depedent variable.  You must have the solution option
	     to get the _betas_fixed_geo dataset*/
	   /*Create an output file with the prediction values*/
       model y= &model_stmt / solution outp=_pred_1 ;
	   /*Specifiy the random effects and the level they are 
	     captured at (geo)*/
       random &model_stmt Intercept / subject=geo;
	   
     RUN;

/*Calculate the Mean Absolute Percentage Error (MAPE)*/
     PROC SQL noprint; 
	  create table 
        Model_Metrics_temp 
      as select  
        count(*) as N,
        (sum(abs((y-Pred)/y))*100) as SUM,
        (calculated SUM)/(calculated N) as MAPE
	  from _pred_1;
     QUIT;


/*Capture the AIC value*/
     DATA AIC;
       set AIC;
       where lowcase(compress(Descr)) in ('aic(smallerisbetter)');
       keep value;
       rename value=AIC;
     RUN;

/*Calculte the number of positive coefficents and signifigant variables*/
     DATA betas;
       set _betas_fixed_geo end=last;
       /*Create count variables for each metrics: Postive Estimates,
	     Negative Estimates, Signifigant Variable, Non-Signifigant Variables*/
       retain Probt_Sig_count Probt_NonSig_count Estimate_Pos_Count Estimate_Neg_Count 0;
       /*These are variables who we don't care about.  Example: We may expect Christmas
	     flag to be negative.  So when choosing a model, we don't care if this term is 
	     negative*/
       where lowcase(effect) not in ('intercept','christmas_flag','start_end_flag','trend');
       /*Add 1 to the count if the estimate is positive*/
       IF Estimate>0 then Estimate_Pos_Count+1;
       /*Add 1 to the count if the estimate is negative*/
       ELSE Estimate_Neg_Count+1;
       /*Add 1 to the the count if the estimate is not signifigant*/
       IF Probt>0.05 then Probt_NonSig_count+1;
       /*Add 1 to the count if the esatime is signifigant*/
       ELSE Probt_Sig_count+1;

	   /*Keep the last row since all the counts exist there*/
       IF last then output;
       /*Drop variables that aren't needed*/
       drop effect df tvalue probt stderr estimate; 
     RUN;


    /*Use PROC REG to calculate the VIF values. These values are output
	  to a dataset called outest*/
    PROC REG data=Mixed_Data_ADSTOCK_log outest=outest(where=(lowcase(_type_)='ridgevif')) 
                  ridge=0 outvif noprint;
	  model y=&model_stmt / vif;
	RUN;
 
    /*Transpose the VIF dataset so all the VIF scores are in a column*/  
	PROC TRANSPOSE data=outest(drop=_MODEL_ _TYPE_ _DEPVAR_ _RIDGE_ _PCOMIT_ 
                                    _RMSE_ Intercept y) 
                   out=outest_trans(rename=(col1=value _name_=var));
	RUN;

	/*Count the number of HIGH and LOW Vif scores*/
	DATA outest_trans;
      set outest_trans end=last;
	  /*Create count variable for high and low vif scores*/
	  retain low_vif_count high_vif_count 0;
	  /*Use <=10 as the low. This can be adjusted as needed*/
      /*Add 1 to the count if the VIF is <= 10*/
      IF value<=10 then low_vif_count+1;
	  /*Add 1 to the count if the VIF >10*/
      ELSE high_vif_count+1; 
	  /*Keep the last row since all counts exist there*/
      IF last then output; 
	  /*Drop variables that aren't needed*/
	  drop var value;
    RUN; 

 /*Combine all the metrics together into a single table*/
    PROC SQL noprint;
 	  create table 
        model_metrics_temp1(drop=sum) 
      as select 
        &key as key, 
        a.*,
        b.*,
        c.*,
        d.AIC
	  from 
        outest_trans a, 
        Model_Metrics_temp b, 
        betas c, 
        AIC D
    ;QUIT;

    DATA model_metrics_temp1;
      set model_metrics_temp1;

      /*Calculate LOW VIF PCNT*/
	  LOW_VIF_PCNT=LOW_VIF_COUNT/(HIGH_VIF_COUNT+LOW_VIF_COUNT); 
      /*Calculate the percent of signifigant variables*/
      Probt_sig_pcnt=probt_sig_count/(probt_sig_count+Probt_NonSig_Count);
      /*Calculate the percentage of positive parameters*/
      Estimate_Pos_pcnt=Estimate_Pos_Count/(Estimate_Neg_Count+Estimate_Pos_Count);
      /*Apply format for readability*/
	  format LOW_VIF_PCNT Probt_sig_pcnt Estimate_Pos_PCNT percent10.2;
    RUN;

    /*Create a final dataset with all the metrics from each model in here*/
	PROC APPEND base=model_metrics data=model_metrics_temp1;
    RUN;
    /*Delete old datasets*/
	PROC DATASETS lib=work nodetails nolist nowarn;
	  delete AIC _pred_1 outest outest_trans  
             Model_Metrics_temp _betas_fixed_geo betas 
             model_metrics_temp1;
	QUIT;
  %END;
%mend;
%mixmodel
/*Put the end time to compare against the start time*/
%put END TIME: %sysfunc(datetime(),datetime14.);


