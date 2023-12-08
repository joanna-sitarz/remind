*** |  (C) 2006-2023 Potsdam Institute for Climate Impact Research (PIK)
*** |  authors, and contributors see CITATION.cff file. This file is part
*** |  of REMIND and licensed under AGPL-3.0-or-later. Under Section 7 of
*** |  AGPL-3.0, you are granted additional permissions described in the
*** |  REMIND License Exception, version 1.0 (see LICENSE file).
*** |  Contact: remind@pik-potsdam.de
*** SOF ./modules/37_industry/subsectors/equations.gms

***------------------------------------------------------
*' Industry final energy balance
***------------------------------------------------------
q37_demFeIndst(ttot,regi,entyFe,emiMkt)$(    ttot.val ge cm_startyear
                                         AND entyFe2Sector(entyFe,"indst") ) ..
  sum(se2fe(entySE,entyFE,te),
    vm_demFeSector_afterTax(ttot,regi,entySE,entyFE,"indst",emiMkt)
  )
  =e=
  sum(fe2ppfEN(entyFE,ppfen_industry_dyn37(in)),
    sum((secInd37_emiMkt(secInd37,emiMkt),secInd37_2_pf(secInd37,in)),
      (
          vm_cesIO(ttot,regi,in)
        + pm_cesdata(ttot,regi,in,"offset_quantity")
      )$(NOT secInd37Prc(secInd37))
    )
  )
$ifthen.cm_subsec_model_steel "%cm_subsec_model_steel%" == "processes"
  +
  sum((secInd37_emiMkt(secInd37Prc,emiMkt),secInd37_tePrc(secInd37Prc,tePrc),tePrc2opmoPrc(tePrc,opmoPrc)),
    p37_specFeDem(ttot,regi,entyFE,tePrc,opmoPrc)
    *
    v37_outflowPrc(ttot,regi,tePrc,opmoPrc)
  )
$endif.cm_subsec_model_steel
;

$ifthen.cm_subsec_model_steel "%cm_subsec_model_steel%" == "processes"
***------------------------------------------------------
*' Material input to production
***------------------------------------------------------
q37_demMatPrc(ttot,regi,mat)$((ttot.val ge cm_startyear) AND matIn(mat))..
    v37_matFlow(ttot,regi,mat)
  =e=
    sum(tePrc2matIn(tePrc,opmoPrc,mat),
      p37_specMatDem(mat,tePrc,opmoPrc)
      *
      v37_outflowPrc(ttot,regi,tePrc,opmoPrc)
    )
;

***------------------------------------------------------
*' Material cost
***------------------------------------------------------
q37_costMat(ttot,regi)$(ttot.val ge cm_startyear)..
    vm_costMatPrc(ttot,regi)
  =e=
    sum(mat,
      p37_priceMat(mat)
      *
      v37_matFlow(ttot,regi,mat))
;

***------------------------------------------------------
*' Output material production
***------------------------------------------------------
q37_prodMat(ttot,regi,mat)$((ttot.val ge cm_startyear) AND matOut(mat))..
    v37_matFlow(ttot,regi,mat)
  =e=
    sum(tePrc2matOut(tePrc,opmoPrc,mat),
      v37_outflowPrc(ttot,regi,tePrc,opmoPrc)
    )
;

***------------------------------------------------------
*' Hand-over to CES
***------------------------------------------------------
q37_mat2ue(ttot,regi,all_in)$((ttot.val ge cm_startyear) AND ppfUePrc(all_in))..
    vm_cesIO(ttot,regi,all_in)
  =e=
    sum(mat2ue(mat,all_in),
      p37_mat2ue(mat,all_in)
      *
      v37_matFlow(ttot,regi,mat)
    )
;

***------------------------------------------------------
*' Definition of capacity constraints
***------------------------------------------------------
q37_limitCapMat(ttot,regi,tePrc)$(ttot.val ge cm_startyear) ..
    sum(tePrc2opmoPrc(tePrc,opmoPrc),
      v37_outflowPrc(ttot,regi,tePrc,opmoPrc)
    )
    =l=
    sum(teMat2rlf(tePrc,rlf),
      vm_capFac(ttot,regi,tePrc) * vm_cap(ttot,regi,tePrc,rlf)
    )
;

$endif.cm_subsec_model_steel

***------------------------------------------------------
*' Thermodynamic limits on subsector energy demand
***------------------------------------------------------
$ifthen.no_calibration "%CES_parameters%" == "load"   !! CES_parameters
q37_energy_limits(ttot,regi,industry_ue_calibration_target_dyn37(out))$(
                             ttot.val gt 2020
$ifthen.cm_subsec_model_steel "%cm_subsec_model_steel%" == "processes"
                             AND NOT ppfUePrc(out)
$endif.cm_subsec_model_steel
			                       AND p37_energy_limit_slope(ttot,regi,out) ) ..
  sum(ces_eff_target_dyn37(out,in), vm_cesIO(ttot,regi,in))
  =g=
    vm_cesIO(ttot,regi,out)
  * p37_energy_limit_slope(ttot,regi,out)
;
$endif.no_calibration

***------------------------------------------------------
*' Limit the share of secondary steel to historic values, fading to 90 % in 2050
***------------------------------------------------------
q37_limit_secondary_steel_share(ttot,regi)$(
         ttot.val ge cm_startyear

$ifthen.fixed_production "%cm_import_EU%" == "bal"   !! cm_import_EU
         !! do not limit steel production shares for fixed production
     AND p37_industry_quantity_targets(ttot,regi,"ue_steel_secondary") eq 0
$endif.fixed_production
$ifthen.exogDem_scen NOT "%cm_exogDem_scen%" == "off"
         !! do not limit steel production shares for fixed production
     AND pm_exogDemScen(ttot,regi,"%cm_exogDem_scen%","ue_steel_secondary") eq 0
$endif.exogDem_scen

                                                                            ) ..
  vm_cesIO(ttot,regi,"ue_steel_secondary")
  =l=
    ( vm_cesIO(ttot,regi,"ue_steel_primary")
    + vm_cesIO(ttot,regi,"ue_steel_secondary")
    )
  * p37_steel_secondary_max_share(ttot,regi)
;

***------------------------------------------------------
*' Compute gross local industry emissions before CCS by multiplying sub-sector energy
*' use with fuel-specific emission factors. (Local means from a hypothetical purely fossil
*' energy mix, as that is what can be captured); vm_emiIndBase itself is not used for emission
*' accounting, just as a CCS baseline.
***------------------------------------------------------
q37_emiIndBase(ttot,regi,entyFE,secInd37)$( ttot.val ge cm_startyear ) ..
    vm_emiIndBase(ttot,regi,entyFE,secInd37)
  =e=
    sum((secInd37_2_pf(secInd37,ppfen_industry_dyn37(in)),fe2ppfen(entyFECC37(entyFE),in)),
        vm_cesIO(ttot,regi,in)
        *
        sum(se2fe(entySEfos,entyFE,te),
            pm_emifac(ttot,regi,entySEfos,entyFE,te,"co2")
        )
    )$(NOT secInd37Prc(secInd37))
$ifthen.cm_subsec_model_steel "%cm_subsec_model_steel%" == "processes"
    +
    sum((secInd37_tePrc(secInd37,tePrc),tePrc2opmoPrc(tePrc,opmoPrc)),
        v37_emiPrc(ttot,regi,entyFE,tePrc,opmoPrc)
    )$(secInd37Prc(secInd37))
$endif.cm_subsec_model_steel
;

$ifthen.cm_subsec_model_steel "%cm_subsec_model_steel%" == "processes"
***------------------------------------------------------
*' Emission from process based industry sector (pre CC)
***------------------------------------------------------
q37_emiPrc(ttot,regi,entyFE,tePrc,opmoPrc)$(ttot.val ge cm_startyear ) ..
    v37_emiPrc(ttot,regi,entyFE,tePrc,opmoPrc)
  =e=
    p37_specFeDem(ttot,regi,entyFE,tePrc,opmoPrc)
    *
    sum(se2fe(entySEfos,entyFE,te),
      pm_emifac(ttot,regi,entySEfos,entyFE,te,"co2"))
    *
    v37_outflowPrc(ttot,regi,tePrc,opmoPrc)
;

***------------------------------------------------------
*' Carbon capture processes can only capture as much co2 as the base process emits
***------------------------------------------------------
q37_limitOutflowCCPrc(ttot,regi,tePrc)$(ttot.val ge cm_startyear ) ..
    sum((entyFE,tePrc2opmoPrc(tePrc,opmoPrc)),
      v37_emiPrc(ttot,regi,entyFE,tePrc,opmoPrc))
  =g=
    sum(tePrc2teCCPrc(tePrc,opmoPrc,teCCPrc,opmoCCPrc),
      1. / p37_captureRate(teCCPrc,opmoCCPrc)
      *
      v37_outflowPrc(ttot,regi,teCCPrc,opmoCCPrc)
    )
;


***------------------------------------------------------
*' Emission captured from process based industry sector
***------------------------------------------------------
q37_emiCCPrc(ttot,regi,emiInd37)$((ttot.val ge cm_startyear ) AND sum(secInd37Prc,secInd37_2_emiInd37(secInd37Prc,emiInd37)) ) ..
    vm_emiIndCCS(ttot,regi,emiInd37)
  =e=
    sum((secInd37_2_emiInd37(secInd37Prc,emiInd37),
         secInd37_tePrc(secInd37Prc,tePrc),
         tePrc2teCCPrc(tePrc,opmoPrc,teCCPrc,opmoCCPrc)),
      v37_outflowPrc(ttot,regi,teCCPrc,opmoCCPrc)
    )
;
$endif.cm_subsec_model_steel

***------------------------------------------------------
*' Compute maximum possible CCS level in industry sub-sectors given the current
*' CO2 price.
***------------------------------------------------------
q37_emiIndCCSmax(ttot,regi,emiInd37)$( ttot.val ge cm_startyear AND NOT sum(secInd37Prc,secInd37_2_emiInd37(secInd37Prc,emiInd37)) ) ..
  v37_emiIndCCSmax(ttot,regi,emiInd37)
  =e=
    !! map sub-sector emissions to sub-sector MACs
    !! otherInd has no CCS, therefore no MAC, cement has both fuel and process
    !! emissions under the same MAC
    sum(emiMac2mac(emiInd37,macInd37),
      !! add cement process emissions, which are calculated in core/preloop
      !! from a econometric fit and might not correspond to energy use (FIXME)
      ( sum((secInd37_2_emiInd37(secInd37,emiInd37),entyFE),
          vm_emiIndBase(ttot,regi,entyFE,secInd37)
        )$( NOT sameas(emiInd37,"co2cement_process") )
      + ( vm_emiIndBase(ttot,regi,"co2cement_process","cement")
        )$( sameas(emiInd37,"co2cement_process") )
      )
    * pm_macSwitch(macInd37)              !! sub-sector CCS available or not
    * pm_macAbatLev(ttot,regi,macInd37)   !! abatement level at current price
  )
;

***------------------------------------------------------
*' Limit industry CCS to maximum possible CCS level.
***------------------------------------------------------
q37_IndCCS(ttot,regi,emiInd37)$( ttot.val ge cm_startyear AND NOT sum(secInd37Prc,secInd37_2_emiInd37(secInd37Prc,emiInd37)) ) ..
  vm_emiIndCCS(ttot,regi,emiInd37)
  =l=
  v37_emiIndCCSmax(ttot,regi,emiInd37)
;

***------------------------------------------------------
*' Limit industry CCS scale-up to sm_macChange (default: 5 % p.a.)
***------------------------------------------------------
q37_limit_IndCCS_growth(ttot,regi,emiInd37) ..
  vm_emiIndCCS(ttot,regi,emiInd37)
  =l=
    vm_emiIndCCS(ttot-1,regi,emiInd37)
  + sum(secInd37_2_emiInd37(secInd37,emiInd37),
      v37_emiIndCCSmax(ttot,regi,emiInd37)
    * sm_macChange
    * pm_ts(ttot)
    )
;

***------------------------------------------------------
*' Fix cement fuel and cement process emissions to the same abatement level.
***------------------------------------------------------
q37_cementCCS(ttot,regi)$(    ttot.val ge cm_startyear
                          AND pm_macswitch("co2cement")
                          AND pm_macAbatLev(ttot,regi,"co2cement") ) ..
    vm_emiIndCCS(ttot,regi,"co2cement")
  * v37_emiIndCCSmax(ttot,regi,"co2cement_process")
  =e=
    vm_emiIndCCS(ttot,regi,"co2cement_process")
  * v37_emiIndCCSmax(ttot,regi,"co2cement")
;

***------------------------------------------------------
*' Calculate industry CCS costs.
***------------------------------------------------------
q37_IndCCSCost(ttot,regi,emiInd37)$( ttot.val ge cm_startyear AND NOT sum(secInd37Prc,secInd37_2_emiInd37(secInd37Prc,emiInd37)) ) ..
  vm_IndCCSCost(ttot,regi,emiInd37)
  =e=
    1e-3
  * pm_macSwitch(emiInd37)
  * ( sum((enty,secInd37_2_emiInd37(secInd37,emiInd37)),
        vm_emiIndBase(ttot,regi,enty,secInd37)
      )$( NOT sameas(emiInd37,"co2cement_process") )
    + ( vm_emiIndBase(ttot,regi,"co2cement_process","cement")
      )$( sameas(emiInd37,"co2cement_process") )
    )
  * sm_dmac
  * sum(emiMac2mac(emiInd37,enty),
      ( pm_macStep(ttot,regi,enty)
      * sum(steps$( ord(steps) eq pm_macStep(ttot,regi,enty) ),
          pm_macAbat(ttot,regi,enty,steps)
        )
      )
    - sum(steps$( ord(steps) le pm_macStep(ttot,regi,enty) ),
        pm_macAbat(ttot,regi,enty,steps)
      )
    )
;


***---------------------------------------------------------------------------
*'  CES markup cost that are accounted in the budget (GDP) to represent sector-specific demand-side transformation cost in industry
***---------------------------------------------------------------------------
q37_costCESmarkup(t,regi,in)$(ppfen_industry_dyn37(in))..
  vm_costCESMkup(t,regi,in)
  =e=
    p37_CESMkup(t,regi,in)
  * (vm_cesIO(t,regi,in) + pm_cesdata(t,regi,in,"offset_quantity"))
;

*** EOF ./modules/37_industry/subsectors/equations.gms
