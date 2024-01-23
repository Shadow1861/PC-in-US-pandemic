clear


global PATH "EC334-summaritive"  
global D    "$PATH\data"     
global R    "$PATH\refs"     
global Out  "$PATH\res"      
cd "$D"


import delimited "$D\PC.csv"

// import fred UNRATE USRECM CPIAUCSL CPILFESL PCEPI PCEPILFE, daterange(01/01/1960 01/01/2024) aggregate(quarterly, avg)
// check the data
summarize * 
br

gen time = yq(year,quarter)
tsset time
sort time
gen ccpi = (cpilfesl - L.cpilfesl)/L.cpilfesl*100 if _n>1
gen cpi = (cpiaucsl - L.cpiaucsl)/L.cpiaucsl*100 if _n>1
gen cpce = (pcepilfe - L.pcepilfe)/L.pcepilfe*100 if _n>1
gen pce = (pcepi - L.pcepi)/L.pcepi*100 if _n>1
gen dum_v = v_u>=1 
gen lnv = log(v_u)
gen s_imp = (import_def - L.import_def)/ L.import_def * 100 if _n>1
gen s_oil = (poilbreusdm - L.poilbreusdm)/ L.poilbreusdm * 100 if _n>1 
gen dgdp = (gdp_def - L.gdp_def) / L.gdp_def * 100 if _n>1
gen emgap = unrate - nrou

local starts 1969 2009 2010 2018 2020
local ends 2010 2019 2023 2023 2023
local expectations michigan_inflation spf_inflation swap_1year swap_5year swap_10year
local inflations cpi pce ccpi cpce dgdp
local shocks s_imp s_oil
local proxs emgap lnv

foreach prox of varlist `proxs' {
	gen `prox'Xdum_v = `prox' * dum_v
}

// plot the ts of labour market tightness
line v_u time if v_u != . 

// replicate the Fig4 in 
local counter = 1
foreach infla of varlist `inflations' {		
	forvalues i=1/3 {
		local start_year = word("`starts'",`i')
		local end_year   = word("`ends'",`i') 
		
		* Create a scatter plot with a fitted line for each period
		graph twoway ///
			(lfit `infla' v_u if inrange(year, `start_year', `end_year') & v_u <= 1, lpattern(solid) lcolor(black)) ///
			(scatter `infla' v_u if inrange(year, `start_year', `end_year') & v_u <= 1, mcolor(blue) msymbol(oh) msize(medium)) ///
			(lfit `infla' v_u if inrange(year, `start_year', `end_year') & v_u > 1, lpattern(solid) lcolor(black)) ///
			(scatter `infla' v_u if inrange(year, `start_year', `end_year') & v_u > 1, mcolor(green) msymbol(oh) msize(medium)) ///
			, xscale(range(0 2)) xtick(0(0.5)2) yscale(range(-0.1 2)) ytick(0 2) legend(off) xtitle("Labour Market Tightness") ytitle("Inflation") name(fig`start_year'_`end_year'_`counter', replace)
		// graph export "$Out\fig\fig`start_year'_`end_year'_`counter'.png"
	}
	local counter = `counter' + 1
}

// do reg on the nonlinear NKPC
// the variable of interest: lnv and the cross
foreach exp in michigan_inflation {
	foreach infla of varlist `inflations' {
		gen gap = `infla' - `exp'
		foreach shock of varlist `shocks' {
			foreach prox of varlist `proxs' {
				est clear
				forvalues i=1/5 {
					local start_year = word("`starts'",`i')
					local end_year   = word("`ends'",`i') 
					eststo: regress gap `prox' `prox'Xdum_v `shock' /// 
						if year>=`start_year' & year<`end_year', vce(robust)
					estadd local Period `start_year'-`end_year'
				}
				esttab using "$Out/gap/gap_`exp'_`infla'_`shock'_`prox'.tex", star(* 0.1 ** 0.05 *** 0.01) ///
					booktabs width(\hsize) stats(r2_a Period N) b(%5.4f) label replace se
			}
		}
		drop gap
	}
}


// do reg on the linear NKPC to compare models
foreach exp in michigan_inflation {
	foreach infla of varlist `inflations' {
		gen gap = `infla' - `exp'
		foreach shock of varlist `shocks' {
			foreach prox of varlist `proxs' {
				est clear
				forvalues i = 1/5 {
					local start_year = word("`starts'", `i')
					local end_year   = word("`ends'", `i') 
					eststo: regress gap `prox' `shock' /// 
						if year >= `start_year' & year < `end_year', vce(robust)
					estadd local Period `start_year' - `end_year'
				}
				esttab using "$Out/gap_l/gap2_`exp'_`infla'_`shock'_`prox'.tex", star(* 0.1 ** 0.05 *** 0.01) ///
					booktabs width(\hsize) stats(r2_a Period N) b(%5.4f) label replace se
			}
		}
		drop gap
	}
}


