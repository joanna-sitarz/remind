*** |  (C) 2006-2023 Potsdam Institute for Climate Impact Research (PIK)
*** |  authors, and contributors see CITATION.cff file. This file is part
*** |  of REMIND and licensed under AGPL-3.0-or-later. Under Section 7 of
*** |  AGPL-3.0, you are granted additional permissions described in the
*** |  REMIND License Exception, version 1.0 (see LICENSE file).
*** |  Contact: remind@pik-potsdam.de
*** SOF ./modules/37_industry/subsectors/postsolve.gms

*** calculation of FE Industry Prices (useful for internal use and reporting
*** purposes)
pm_FEPrice(ttot,regi,entyFE,"indst",emiMkt)$( abs(qm_budget.m(ttot,regi)) gt sm_eps )
  = q37_demFeIndst.m(ttot,regi,entyFE,emiMkt)
  / qm_budget.m(ttot,regi);

*** calculate reporting parameters for FE per subsector and SE origin to make R
*** reporting easier

$ifthen.process_based_steel "%cm_process_based_steel%" == "on"                 !! cm_process_based_steel
o37_demFePrc(ttot,regi,entyFE,tePrc,opmoPrc)$(p37_specFEDem(ttot,regi,entyFE,tePrc,opmoPrc))
  = v37_outflowPrc.l(ttot,regi,tePrc,opmoPrc)
    * p37_specFEDem(ttot,regi,entyFE,tePrc,opmoPrc)
;
$endif.process_based_steel

*** total FE per energy carrier and emissions market in industry (sum over
*** subsectors)
o37_demFeIndTotEn(ttot,regi,entyFe,emiMkt)
  = sum((fe2ppfEn37(entyFe,in),secInd37_2_pf(secInd37,in),
                         secInd37_emiMkt(secInd37,emiMkt))$(NOT secInd37Prc(secInd37)),
      (vm_cesIO.l(ttot,regi,in)
      +pm_cesdata(ttot,regi,in,"offset_quantity"))
    )
$ifthen.process_based_steel "%cm_process_based_steel%" == "on"                 !! cm_process_based_steel
    +
  sum((secInd37_emiMkt(secInd37Prc,emiMkt),secInd37_tePrc(secInd37Prc,tePrc),tePrc2opmoPrc(tePrc,opmoPrc)),
    o37_demFePrc(ttot,regi,entyFE,tePrc,opmoPrc)
  )
$endif.process_based_steel
;

*** share of subsector in FE industry energy carriers and emissions markets
o37_shIndFE(ttot,regi,entyFe,secInd37,emiMkt)$(
                                    o37_demFeIndTotEn(ttot,regi,entyFe,emiMkt) )
  =
  ( sum(( fe2ppfEn37(entyFe,in),
          secInd37_2_pf(secInd37,in),
          secInd37_emiMkt(secInd37,emiMkt))$(NOT secInd37Prc(secInd37)),
      (vm_cesIO.l(ttot,regi,in)
      +pm_cesdata(ttot,regi,in,"offset_quantity"))
  )
$ifthen.process_based_steel "%cm_process_based_steel%" == "on"                 !! cm_process_based_steel
  +
  sum((secInd37_emiMkt(secInd37Prc,emiMkt),secInd37_tePrc(secInd37Prc,tePrc),tePrc2opmoPrc(tePrc,opmoPrc)),
    o37_demFePrc(ttot,regi,entyFE,tePrc,opmoPrc)
  )$(secInd37Prc(secInd37))
$endif.process_based_steel
  )
  / o37_demFeIndTotEn(ttot,regi,entyFe,emiMkt)
;


*** FE per subsector and energy carriers
o37_demFeIndSub(ttot,regi,entySe,entyFe,secInd37,emiMkt)
  = sum(secInd37_emiMkt(secInd37,emiMkt),
      o37_shIndFE(ttot,regi,entyFe,secInd37,emiMkt)
    * vm_demFeSector_afterTax.l(ttot,regi,entySe,entyFe,"indst",emiMkt)
  );

*** industry captured fuel CO2
pm_IndstCO2Captured(ttot,regi,entySE,entyFE(entyFEcc37),secInd37,emiMkt)$(
                     macBaseInd37(entyFE,secInd37)
                 AND sum(entyFE2, vm_emiIndBase.l(ttot,regi,entyFE2,secInd37)) )
  = ( o37_demFEindsub(ttot,regi,entySE,entyFE,secInd37,emiMkt)
    * sum(se2fe(entySE2,entyFE,te),
        !! collapse entySE dimension, so emission factors apply to all entyFE
	!! regardless or origin, and therefore entySEbio and entySEsyn have
	!! non-zero emission factors
        pm_emifac(ttot,regi,entySE2,entyFE,te,"co2")
      )
    ) !! subsector emissions (smokestack, i.e. including biomass & synfuels)

  * ( sum(secInd37_2_emiInd37(secInd37,emiInd37(emiInd37_fuel)),
      vm_emiIndCCS.l(ttot,regi,emiInd37)
      ) !! subsector captured energy emissions

    / sum(entyFE2,
        vm_emiIndBase.l(ttot,regi,entyFE2,secInd37)
      ) !! subsector total energy emissions
    ) !! subsector capture share
;
$ifthen.process_based_steel "%cm_process_based_steel%" == "on"                 !! cm_process_based_steel

!! LEFT (OUTDATED)
!!o37_prodIndRoute(ttot,regi,"sesteel","seceaf") = v37_outflowPrc.l(ttot,regi,"eaf","sec");
!!
!!o37_prodIndRoute(ttot,regi,"prsteel","idreaf_ng_ccs")
!!  =    v37_outflowPrc.l(ttot,regi,"idrcc","standard")
!!    /( p37_captureRate("idrcc","standard")
!!     * p37_specMatDem("driron","eaf","pri"));
!!o37_prodIndRoute(ttot,regi,"prsteel","idreaf_ng")
!!  =   v37_outflowPrc.l(ttot,regi,"idr","ng")
!!    / p37_specMatDem("driron","eaf","pri")
!!    - o37_prodIndRoute(ttot,regi,"prsteel","idreaf_ng_ccs");
!!o37_prodIndRoute(ttot,regi,"prsteel","idreaf_h2")
!!  =   v37_outflowPrc.l(ttot,regi,"idr","h2")
!!    / p37_specMatDem("driron","eaf","pri");
!!
!!o37_prodIndRoute(ttot,regi,"prsteel","bfbof_ccs")
!!  =    v37_outflowPrc.l(ttot,regi,"bfcc","standard")
!!    /( p37_captureRate("bfcc","standard")
!!     * p37_specMatDem("pigiron","bof","unheated"));
!!o37_prodIndRoute(ttot,regi,"prsteel","bfbof")
!!  =   v37_outflowPrc.l(ttot,regi,"bf","standard")
!!    / p37_specMatDem("pigiron","bof","unheated")
!!    - o37_prodIndRoute(ttot,regi,"prsteel","bfbof_ccs");


o37_relativeOutflow(ttot,regi,tePrc,opmoPrc)$tePrc2opmoPrc(tePrc,opmoPrc) = 1.

loop((tePrc1,opmoPrc1,tePrc2,opmoPrc2,mat)$(
                tePrc2matIn(tePrc2,opmoPrc2,mat)
            AND tePrc2matOut(tePrc1,opmoPrc1,mat)),
  o37_relativeOutflow(ttot,regi,tePrc1,opmoPrc1)
    = p37_specMatDem(mat,tePrc2,opmoPrc2)
    * o37_relativeOutflow(ttot,regi,tePrc2,opmoPrc2); !! should be one; becomes relevant for more than two stages
);

loop((tePrc,opmoPrc,teCCPrc,opmoCCPrc)$(
                          tePrc2teCCPrc(tePrc,opmoPrc,teCCPrc,opmoCCPrc)),
  o37_relativeOutflow(ttot,regi,teCCPrc,opmoCCPrc)
    = p37_captureRate(teCCPrc,opmoCCPrc)
      sum(entyFe,
        p37_specFeDem(ttot,regi,entyFE,tePrc,opmoPrc)
        *
        sum(se2fe(entySEfos,entyFE,te),
          pm_emifac(ttot,regi,entySEfos,entyFE,te,"co2")))
    * o37_relativeOutflow(ttot,regi,tePrc,opmoPrc);
);


!!____________________________________________________________________________
!! determine shares of v37_outflowPrc that belong to a certain route
!!____________________________________________________________________________
!! init all to 1
o37_shareRoute(ttot,regi,tePrc,opmoPrc,route)$tePrc2route(tePrc,opmoPrc,route) = 1.

loop((tePrc,opmoPrc,teCCPrc,opmoCCPrc,route)$(
                          tePrc2teCCPrc(tePrc,opmoPrc,teCCPrc,opmoCCPrc)
                      AND tePrc2route(teCCPrc,opmoCCPrc,route)),

  !! share of first-stage tech with CCS
  o37_shareRoute(ttot,regi,tePrc,opmoPrc,route)$(sum(entyFE,v37_emiPrc.l(ttot,regi,entyFE,tePrc,opmoPrc)) gt 0.)
    = (   v37_outflowPrc.l(ttot,regi,teCCPrc,opmoCCPrc)
        / p37_captureRate(teCCPrc,opmoCCPrc))
      / sum(entyFE,v37_emiPrc.l(ttot,regi,entyFE,tePrc,opmoPrc));

  !! share of first-stage tech without CCS
  loop(route2$(        tePrc2route(tePrc,opmoPrc,route2)
               AND NOT tePrc2route(teCCPrc,opmoCCPrc,route2)),
    o37_shareRoute(ttot,regi,tePrc,opmoPrc,route2)
      = 1. - o37_shareRoute(ttot,regi,tePrc,opmoPrc,route);
  );
);

!! second stage
loop((tePrc1,opmoPrc1,tePrc2,opmoPrc2,mat,route)$(
                tePrc2matIn(tePrc2,opmoPrc2,mat)
            AND tePrc2matOut(tePrc1,opmoPrc1,mat)
            AND tePrc2route(tePrc1,opmoPrc1,route)
            AND tePrc2route(tePrc2,opmoPrc2,route)),
  !! The share of second-stage tech (such as eaf) which belongs to a certain route equals...
  o37_shareRoute(ttot,regi,tePrc2,opmoPrc2,route)$(v37_outflowPrc.l(ttot,regi,tePrc2,opmoPrc2) gt 0.)
  !! ...the outflow of the first-stage tech (such as idr) which provides the input material (such as driron) to the second-stage...
  =   v37_outflowPrc.l(ttot,regi,tePrc1,opmoPrc1)
    !! ...times the share of that 1st stage tech which belongs to a certain route
    * o37_shareRoute(ttot,regi,tePrc1,opmoPrc1,route)
    !! divided by total amount of that input material required by second-stage tech
    / ( v37_outflowPrc.l(ttot,regi,tePrc2,opmoPrc2)
      * p37_specMatDem(mat,tePrc2,opmoPrc2));
);

!! LEFT AS EXAMPLE:

!!!! first stage
!!o37_shareRoute(ttot,regi,"idr","ng","idreaf_ng_ccs")
!!  = (   v37_outflowPrc.l(ttot,regi,"idrcc","standard")
!!      / p37_captureRate("idrcc","standard"))
!!    / v37_outflowPrc.l(ttot,regi,"idr","ng");
!!o37_shareRoute(ttot,regi,"idr","ng","idreaf_ng")
!!  = 1. - o37_shareRoute(ttot,regi,"idr","ng","idreaf_ng_ccs");
!!!! second stage
!!o37_shareRoute(ttot,regi,"eaf","pri","idreaf_ng_ccs")
!!  =   v37_outflowPrc.l(ttot,regi,"idr","ng")
!!    * o37_shareRoute(ttot,regi,"idr","ng","idreaf_ng_ccs")
!!    / ( v37_outflowPrc.l(ttot,regi,"eaf","pri")
!!      * p37_specMatDem("driron","eaf","pri"));

!!____________________________________________________________________________
!! determine production and FE demand by route
!!____________________________________________________________________________
loop((mat,route)$(matFin(mat)),
  o37_ProdIndRoute(ttot,regi,mat,route)
    = sum((tePrc,opmoPrc)$(    tePrc2matOut(tePrc,opmoPrc,mat)
                           AND tePrc2route(tePrc,opmoPrc,route)),
        v37_outflowPrc.l(ttot,regi,tePrc,opmoPrc)
          * o37_shareRoute(ttot,regi,tePrc,opmoPrc,route)
      );
);

!!
o37_demFeIndRoute(ttot,regi,entyFE,tePrc,route,secInd37) = 0.;
loop((entyFE,route,tePrc,opmoPrc,secInd37)$(    tePrc2route(tePrc,opmoPrc,route)
                                            AND secInd37_tePrc(secInd37,tePrc)
                                            AND (p37_specFeDemTarget(entyFE,tePrc,opmoPrc) gt 0.) ),
  o37_demFeIndRoute(ttot,regi,entyFE,tePrc,route,secInd37)
  = o37_demFeIndRoute(ttot,regi,entyFE,tePrc,route,secInd37) !!sum (only necessary if several opmodes for one route)
    + v37_outflowPrc.l(ttot,regi,tePrc,opmoPrc)
      * o37_shareRoute(ttot,regi,tePrc,opmoPrc,route)
      * p37_specFeDem(ttot,regi,entyFE,tePrc,opmoPrc);
);

!! TODO weighting of CAPEX, OPEX also requires p37_specMatDem; BUT since specific, might not need o37_shareRoute
!! Maybe all of the above is only good for compareScenarios, and LCOP still needs own R code?

!!____________________________________________________________________________

$endif.process_based_steel

*** EOF ./modules/37_industry/subsectors/postsolve.gms
