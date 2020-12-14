/*********************AD STOCK MACRO*****************************\
The ad-stock macro has six inputs:
rr= retetion rate, or the % of an input variable retained for that
    period. Input ALL the rates you want to apply to the dataset
    using a '|' as the delimiter.  We can use proc contents and 
    proc sql for this.
dsin= The datset that contains the data to be ad-stocked
dsout= The new dataset with the ad-stocked variables
varlist_dsn= The dataset that contains a single column whose values
             list of variables that will be ad-stocked in the dsin
             dataset
varlist_var= The single variable in varlist_dsn
by_var= Group processing for each ad-stock.  Typically the by group
        processing is done by geography/date

Each new variable has _A&RR appended to the end.  Please adjust your
variable length as needed.
\****************************************************************/

%macro adstock(rr=,dsin=, dsout=, varlist_dsn=, varlist_var=, by_var=);

/*Load the variables to be ad-stocked into a macro variable using
  '|' as a deliminter.*/
PROC SQL noprint;
  select &varlist_var into :varlist separated by '|';         
  from &varlist_dsn
QUIT;

/*Sort the data for by group processing*/
PROC SORT data=&dsin;                                       
  by &by_var;
RUN;

/*Create the ad-stocks here*/
DATA &dsout;
  set &dsin;
  by &by_var;
 

/*This do loop will iterate through each variable we want to ad-stock*/
%DO i=1 %to %sysfunc(countw(&varlist,'|'));
    /*This do loop will iterate through each ad-stock level specified*/
    %DO j=1 %to %sysfunc(countw(&rr,'|'));
        /* XXX_DEC_AXX variables will need to be retain so we can apply
	       the correct amount from the previous observation to the current*/
        retain %scan(&varlist,&i,'|')_DEC_%scan(&rr,&j,'|'); 
         

        /*Special case for the first observation since it has no previous values*/
        IF FIRST.%scan(&by_var,1) then do;                               
            /*Represents that there is no previous value*/
            %scan(&varlist,&i,'|')_NEW=0;
			/*Calculate the amount that goes to the next observation*/
			%scan(&varlist,&i,'|')_DEC_%scan(&rr,&j,'|')=(1-(%scan(&rr,&j,'|')/100))*%scan(&varlist,&i,'|');  
            /*Calculate the amount that stays with the current observation*/
            %scan(&varlist,&i,'|')_RET_%scan(&rr,&j,'|')=(%scan(&rr,&j,'|')/100)*%scan(&varlist,&i,'|');       

        END;
        
		/*Calculate the ad-stock for all the remaining observations*/
        ELSE DO;
		   /*Calculte the amount that goes into this observation as well asthe amount 
		     that carried over from the previous observation*/
           %scan(&varlist,&i,'|')_NEW=%scan(&varlist,&i,'|')+%scan(&varlist,&i,'|')_DEC_%scan(&rr,&j,'|');
           /*Calculate the amount that will be carried over to the next observation*/
           %scan(&varlist,&i,'|')_DEC_%scan(&rr,&j,'|')=(1-(%scan(&rr,&j,'|')/100))*%scan(&varlist,&i,'|')_NEW;  
           /*Calculate the amount that stays with this observation*/
           %scan(&varlist,&i,'|')_RET_%scan(&rr,&j,'|')=(%scan(&rr,&j,'|')/100)*%scan(&varlist,&i,'|')_NEW;      
	    END;
   
        /*Rename _RET_VAR to _A** to make it more readable in the dataset*/
        rename %scan(&varlist,&i,'|')_RET_%scan(&rr,&j,'|')=%scan(&varlist,&i,'|')_A%scan(&rr,&j,'|');	   
        /*Drop the DEC/NEW varabiles*/
        drop  %scan(&varlist,&i,'|')_DEC_%scan(&rr,&j,'|') %scan(&varlist,&i,'|')_NEW;
    %END;
%END; 
RUN;
%MEND;
/*End of Macro!  The next part will show the datasets and how to make a call!*/

/*Use proc contents to create a dataset with all the variables in 
  the input dataset. These variables will be put into a dataset called varlist_dsn*/
PROC CONTENTS data=MixedData out=varlist_dsn(keep=name) nodetails noprint;
RUN;

/*Keep the values that need the ad-stock transformation*/
DATA varlist_dsn;
  set varlist_dsn;
  where lowcase(compress(name)) in ('x1','x2','x3','x4','x5');
  rename name=varlist;
RUN;

/*Perform ad-stock transformations on each applicable variables*/
%adstock(rr=10|20|30|40|50|60|70|80|90, 
         dsin=MixedData, 
         dsout=Mixed_Data_ADSTOCK, 
         varlist_dsn=varlist_dsn, 
         varlist_var=varlist, 
         by_var=Geo Date);
