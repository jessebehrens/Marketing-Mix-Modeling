
/********************LOG MACRO***********************************************\
The log macro has five inputs:
dsin= The datset that contains the data to be logged
dsout= The new dataset with the logged variables
varlist_dsn= The dataset that contains a single column whose values
             list of variables that will be logged in the dsin
             dataset
varlist_var= The single variable in varlist_dsn

Each new variable has NOTHING appended to the end.  
\****************************************************************/

%macro log(dsin=, dsout=, varlist_dsn=, varlist_var=);

/*Load variables to be logged into a macro variable using '|' 
  as the deliminter*/
PROC SQL noprint;
  select &varlist_var into :varlist separated by '|'
  from &varlist_dsn
QUIT;

/*Dataset that has the variables to be logged*/
DATA &dsout;
  set &dsin;
    /*Iterate through each variable that needs to be lagged*/
    %DO i=1 %to %sysfunc(countw(&varlist,'|'));
      /*Log each variable and add 1 to handle 0 values. All 
	    variables should be non-negative*/
      %scan(&varlist,&i,'|')=log(%scan(&varlist,&i,'|')+1); 
    %END; 
%mend;


PROC CONTENTS data=Mixed_Data_ADSTOCK_lag out=varlist_dsn(keep=name) nodetails noprint;
RUN;

DATA varlist_dsn;
  set varlist_dsn;
  where lowcase(compress(name)) not in ('date','epsilon','geo','geo_rand','region','y');
  rename name=varlist;
RUN;
/*Apply lag to the dataset*/
%log(dsin=Mixed_Data_ADSTOCK_lag, 
     dsout=Mixed_Data_ADSTOCK_log, 
     varlist_dsn=varlist_dsn,
     varlist_var=varlist);

/*Delete intermediate datasets*/
PROC DATASETS lib=work nodetails nolist nowarn;
  delete Mixed_Data_ADSTOCK_lag;
QUIT;
