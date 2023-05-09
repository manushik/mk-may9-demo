*PURPOSE: This do-file makes the comprehensive household and attrition dataset across the three waves.
*AUTHOR: Manushi 
*LAST UPDATED:  03/02/2023


**new
********************************************************************************
*OPENING COMMANDS
********************************************************************************
version 17
clear
set more off


********************************************************************************
*DIRECTORY GLOBALS
********************************************************************************
if "`c(username)'"=="jgn6989" {
      local onedrive "X:\Northwestern University\Andre J Nickow - Ghana_Panel_Complete"
	  local paneldata "X:\Northwestern University\Andre J Nickow - Ghana_Panel_Complete\Ghana_Panel_Public\Data"
	  local misc "X:\Northwestern University\Andre J Nickow - Ghana_Panel_Complete\Miscellaneous"
	  local wave4 "X:\Northwestern University\Andre J Nickow - Ghana_Panel_Complete\Wave 4 Project Folder\Preliminary Data\Raw"
}


if "`c(username)'"=="ani831" {
      local onedrive "X:\OneDrive - Northwestern University\_FromNUBox\Ghana_Panel_Complete"
                local paneldata "X:\OneDrive - Northwestern University\_FromNUBox\Ghana_Panel_Complete\Ghana_Panel_Public\Data"
                local misc "X:\OneDrive - Northwestern University\_FromNUBox\Ghana_Panel_Complete\Miscellaneous"
}

else if "`c(username)'"=="udry" {
     global onedrive =     "X:\Northwestern University\Andre J Nickow - Ghana_Panel_Complete"
	 local paneldata "X:\Northwestern University\Andre J Nickow - Ghana_Panel_Complete\Ghana_Panel_Public\Data"

}




				
global onedrive `onedrive'
global paneldata `paneldata'
global misc `misc'
global wave4 `wave4'


********************************************************************************
*MERGE MAIN HOUSEHOLD LISTS TO CREATE VARIABLES DEFINING WHICH WAVES EACH HOUSEHOLD WAS INTERVIEWED IN
********************************************************************************

use "${paneldata}\W1\key_hhld_info", clear

*Dummy indicating that the hh was in W1

collapse (first)regioncode (first)districtcode, by(FPrimary)


gen w1_int = 1

merge 1:1 FPrimary using "${paneldata}\W2\01a_consent", keepusing(timesmoved)


	*Dummy indicating that the hh was in W2
gen w2_int = _merge == 2|_merge == 3
gen w12_split = _merge == 2
rename timesmoved w12_timesmoved

*assume that people for whom timesmoved between wave 1 and 2 is missing - did not move 
replace w12_timesmoved=0 if w12_timesmoved==. & w2_int==1



drop _merge

merge 1:1 FPrimary using "${paneldata}\W3\00_hh_info"

*Dummy that the hh was  in W3
gen w3_int = _merge == 2|_merge == 3
gen w23_split = _merge == 2


* Check whether variable for splitting off between Waves 2 and 3 (w23_split) matches Wave 3 "round" variable. Also, if variable for households having moved in between Waves 2 and 3 match with th "round" variable.

tab round
* 862 split off
* 174 wholly moved


count if w23_split==0 & round==2
*no main households are split-offs acc to round variable 

count if w23_split==1 & round!=2
*58 hh which split off in wave are part of main round:  may be if the splitoffs moved nearby and they were able to squeeze them in during the main "round", but now this is a helpful data point so that we can take a closer look at these households and if needed check with University of Ghana

tab round moved, mi
* round does not give correct hh status, but the round they were interviewed 
label var round "Round in which hh was interviewed" 


drop _merge

merge 1:1 FPrimary using "${paneldata}\W3\01a_consent.dta", keepusing(timesmoved)

rename timesmoved w23_timesmoved
ren moved moved_w3
ren round round_w3
ren region region_w3
ren district district_w3
drop remnant 
ren FPrimary_original FPrimary_original_w3
ren hhmid_original hhmid_original_w3
ren last_wave last_wave_w3


drop _merge



replace w1_int = 0 if mi(w1_int)
replace w2_int = 0 if mi(w2_int)
replace w3_int = 0 if mi(w3_int)



	*Generate attrition variables
gen w12_att = (w1_int == 1 & w2_int == 0)
gen w23_att = (w2_int== 1 & w3_int == 0)
gen w13_return = (w1_int == 1 & w2_int == 0 & w3_int == 1)




*renaming region and distict codes for W1 and W3\00_hh_info

ren regioncode r_code_w1
ren districtcode d_code_w1
ren r_code r_code_w3
ren d_code d_code_w3
ren comm_code comm_code_w3 


*take district and region info for W2 

preserve
tempfile id_w2

use "${onedrive}\Miscellaneous\Geographic\w2_geographic",clear
collapse (first)regioncode (first)districtcode (first)eacode, by(FPrimary)
keep regioncode districtcode FPrimary eacode 

save `id_w2'
restore

merge 1:1 FPrimary using `id_w2', nogen

ren regioncode r_code_w2
ren districtcode d_code_w2
ren eacode eacode_w2



* checks 

*Wave 2 
assert substr(FPrimary,1,1)!="1" if w12_split == 1 & w3_int==0
*hh which are splitoff from w1-w2 have either 2,3,4,5,6 as first digit 


assert substr(FPrimary,1,1)=="1" if w12_split != 1 & w23_split !=1 
*all main households have 1 as first digit 

*Wave 3 

assert substr(FPrimary,1,1)!="1"| strlen(FPrimary)==10 if w23_split == 1 & w3_int==1
*split-offs in wave 3 should be either not starting with 1, or 10 digits if they start with 1

assert w23_split == 1|w12_split==1 if substr(FPrimary,1,1)!="1" 
* all households that don't start with 1 are split-offs 

*Reasons for attrition in wave 2 

merge 1:1 FPrimary using "${onedrive}\Ghana Panel PII\Tracking data\Wave 2\tracking_bvisit.dta", keepusing(lateststatus return2014) nogen

ren lateststatus lateststatus_w2
tab lateststatus_w2 if  w2_int !=1 & w1_int==1,m
tab return2014 if  w2_int !=1 & w1_int==1,m


*Reasons for attrition in wave 3

preserve
import delimited using "${onedrive}\Ghana Panel PII\Tracking Data\Wave 3\wave_3_household_tracking_WIDE", clear

keep hh_id* hh_in_comm_check_* hh_in_comm_confirm_* hh_upd_location* hh_located_* hh_notfound_reason_* 
order hh_id* hh_in_comm_check_* hh_in_comm_confirm_* hh_upd_location* hh_located_* hh_notfound_reason_* 

tostring( hh_notfound_reason_osp_*) ,replace

gen i= _n
reshape long hh_id_ hh_in_comm_check_ hh_in_comm_confirm_ hh_upd_location_ hh_located_ hh_notfound_reason_ hh_notfound_reason_osp_, i(i) j(j)
drop if hh_id_==.
ren hh_id_ FPrimary
sort FPrimary
tostring(FPrimary) ,replace

gen lateststatus_w3=. 
replace lateststatus_w3=2 if hh_upd_location_==5 & hh_located==5
replace lateststatus_w3=5 if hh_in_comm_check_ == -777| hh_in_comm_confirm_ == -777
replace lateststatus_w3=3 if hh_in_comm_check_ == 1| hh_in_comm_confirm_ == 1
replace lateststatus_w3=4 if (hh_in_comm_confirm_ == 5 & hh_upd_location_==1)|(hh_in_comm_confirm_ == 5 & hh_located==1)


label define lateststatus 2 "Unable to Locate" 5 "All Died" 4 "Found - outside the community " 3 "Found - inside the community"
label values lateststatus_w3 lateststatus


 
save "${onedrive}\Ghana Panel PII\Tracking Data\Wave 3\wave_3_household_tracking", replace

restore

merge 1:m FPrimary using "${onedrive}\Ghana Panel PII\Tracking Data\Wave 3\wave_3_household_tracking", nogen keepusing (lateststatus_w3)

*drop duplicates of households for which latest status is same
duplicates drop FPrimary lateststatus_w3 if w3_int !=1 & w2_int==1, force

duplicates tag FPrimary if w3_int !=1 & w2_int==1, gen(dup)

drop if dup==1 & lateststatus_w3==.
drop if lateststatus_w3==2 & FPrimary=="106211002"
drop dup
tab lateststatus_w3 if  w3_int !=1 & w2_int==1,m
duplicates drop FPrimary, force 





******
*WAVE 4
******



merge 1:1 FPrimary using "${onedrive}\\Wave 4 Project Folder\Preliminary Data\raw\00_hh_info.dta", keepusing(r_code d_code split_off) 

ren split_off w34_split
ren r_code r_code_w4
ren d_code d_code_w4

count if w3_int ==1 & _merge==1
*635 hh in wave 3 but survey but not in wave 4 - attrition


gen w4_int=1 if _merge==3|_merge==2
replace w4_int=0 if _merge==1

gen w34_att = (w3_int== 1 & w4_int == 0)


*reason for attrition b/w wave 3 and 4 

drop _merge
preserve
tempfile wave4
use "${onedrive}\\Wave 4 Project Folder\Preliminary Data\raw\Sec0 Tracking & Identifiers.dta",clear
ren s1_hh_id FPrimary
tostring(FPrimary), replace
save `wave4'
restore

merge 1:1 FPrimary using `wave4', keepusing(incomplete_reason incomplete_reason_osp) 

ren incomplete_reason lateststatus_w4

tab lateststatus_w4 if w34_att==1, m


*if h was in main, split off 12 , or 23, 34

gen split_off = 0 if w12_split==0 & w23_split==0 & w34_split==0
replace split_off = 1 if w12_split==1
replace split_off = 2 if w23_split==1
replace split_off = 3 if w34_split==1



*LABELS

lab var w1_int "Households interview in W1"
lab var w2_int "Households interview in W2"
lab var w3_int "Households interview in W3"
lab var w4_int "Households interview in W4"
lab var w12_split "Households split between W1 & W2"
lab var w23_split "Households split between W2 & W3"
lab var w34_split "Households split between W3 & W4"
lab var w12_att "Households that left between W1 & W2"
lab var w23_att "Households that left between W2 & W3"
lab var w34_att "Households that left between W3 & W4"
lab var w13_return "Households that returned between W1 & W3"
lab var split_off "Household is main or a split-off in either waves"


*Cetegorical variables: Value Labels

recode moved (5=0)
label define yn 1 "Yes" 0 "No"
label values moved yn

foreach var in w1_int w12_split w12_att ///
 w2_int w23_split w23_att w3_int w4_int w34_att w34_split {
 	  label values `var' yn
 }   
         
label define split 0 "Main"  1 "Split b/w 1 & 2"  2 "Split b/w 2 & 3" 3 "Split b/w 3 & 4"
label values split_off split


*SAVE THE DATASET*

drop _merge
order FPrimary r_code_w1 d_code_w1 r_code_w2 d_code_w2 eacode_w2 r_code_w3 region_w3 d_code_w3 district_w3 comm_code_w3 r_code_w4 d_code_w4 FPrimary_original_w3 hhmid_original_w3 round_w3 moved_w3 last_wave_w3 w1_int w12_split w12_timesmoved w12_att w2_int w23_split w23_timesmoved w23_att w3_int w13_return w34_att w34_split w4_int



cd "${misc}\Composition and Attrition\Data"
save "Composition_cross_wave_hh", replace




***merging data to understand no. of individuals in the households which attrited, or split-off***

preserve
merge 1:m FPrimary using "${paneldata}\W1\key_hhld_info"

unique FPrimary if w12_att==1
*2164
restore

preserve
merge 1:m FPrimary using "${paneldata}\W2\01b2_roster"

unique FPrimary if w23_att==1
*903
restore

preserve
merge 1:m FPrimary using "${paneldata}\W3\01b2_roster"

unique FPrimary if w34_att==1
*1303
restore

*split -off individuals in the number of hh which split off 


use "${paneldata}\W1\key_hhld_info", clear 
duplicates drop FPrimary,force
drop hhmid
gen w1_int=1
*Dummy indicating that the hh was in W1



merge 1:m FPrimary using "${paneldata}\W2\01b2_roster"


gen w12_split = _merge == 2
gen w2_int=1 if _merge == 3

unique FPrimary if w12_split==1
*818

duplicates drop FPrimary,force
drop hhmid
drop _merge

merge 1:m FPrimary using "${paneldata}\W3\01b2_roster"

gen w23_split = _merge == 2
gen w3_int = 1 if _merge==3

unique FPrimary if w23_split==1
* 2301 

unique FPrimary if w1_int==1 & w3_int==1 & w2_int!=1
*1497

duplicates drop FPrimary,force
drop hhmid
drop _merge

preserve   

tempfile w4
use "${wave4}\sec1 - household roster", clear 
rename s1_hh_id FPrimary
save `w4'
restore 

merge 1:m FPrimary using `w4'
gen w34_split = _merge == 2
unique FPrimary if w34_split==1




