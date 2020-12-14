
/********************LAG MACRO***********************************************\
The lag macro has six inputs:
dsin= The datset that was ad-stocked
dsout= The new dataset with the ad-stocked variables and lagged
varlist_dsn= The dataset that contains a single column whose values
             list of variables that will be lagged in the dsin
             dataset
varlist_var= The signgle variable in varlist_dsn
by_var= Group processing for each lagged. Typically at the geo level.
        Assumes that the first variable is a grouping (example:Geo) and the
        second variable is a date.
lag= The number of lags to be applied to the dataset

Each new variable has _L&i appended to the end.  Please adjust your
variable length as needed.
\****************************************************************/
 
%macro lag(dsin=, dsout=, varlist_dsn=, varlist_var=, by_var=,lag=); 

/*Load variables to be lagged into a macro variable using '|' 
  as the deliminter*/
PROC SQL noprint;
  select &varlist_var into :varlist separated by '|'
  from &varlist_dsn
QUIT;

/*Sort the data for by group processing*/
PROC SORT data=&dsin;                                                
  by &by_var;
RUN;

/*Create the lag variables define by the &lag= macro*/
DATA &dsout;
  set &dsin;
  by &by_var;
  retain count; 
   
   /*Create a count variable for the first variable
     in the &by_group*/
   IF FIRST.%scan(&by_var,1) then count=1;
   ELSE count=count+1;

   /*Iterate through each variable that needs to be lagged*/
   %DO i=1 %to %sysfunc(countw(&varlist,'|'));
     /*Iterate through the number of lags*/
     %DO j=1 %to &lag;
	   /*Apply lag to each variable. New variables are created
	     and _L&j is appeneded to the new variable.*/
	   %scan(&varlist,&i,'|')_L&j=lag&j(%scan(&varlist,&i,'|'));  
       /*Since we have groups (example:GEO) this logic makes sure
	     it doesn't calculate a lag based on a previous groups 
	     value.  That is, If we are calculate 4 lags, and in the
	     third time period of Group 1, lag 4 should be missing.*/
       IF count<=&j then %scan(&varlist,&i,'|')_L&j=.;
     %END; 
   %END; 
    /*Count is not needed after the lags have been calculated*/
    drop count;
RUN;
%mend;


/*Example Call*/

/*Use proc contents to create a dataset with all the variables in 
  the Mixed_data dataset. These variables will be put into a dataset
  called varlist_dsn.  This includes the ad-stock variables*/
PROC CONTENTS data=Mixed_Data_ADSTOCK out=varlist_dsn(keep=name) nodetails noprint;
RUN;

/*Drop the variables that don't need to be lagged*/
DATA varlist_dsn;
  set varlist_dsn;
  where lowcase(compress(name)) not in ('date','epsilon','geo','geo_rand','region','y');
  rename name=varlist;
RUN;
/*Apply lag to the dataset*/
%lag(dsin=Mixed_Data_ADSTOCK, 
     dsout=Mixed_Data_ADSTOCK_lag, 
     varlist_dsn=varlist_dsn,
     varlist_var=varlist, 
     by_var=Geo Date, 
     lag=2);

/*Delete intermediate datasets*/
PROC DATASETS lib=work nodetails nolist nowarn;
  delete Mixed_Data_ADSTOCK_DMA_ADSTOCK;
QUIT;


