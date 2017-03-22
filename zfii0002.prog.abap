report zfii0002 .


*----------------------------------------------------------------------*
*- Declarações Globais
*----------------------------------------------------------------------*
data:
  lo_ativos  type ref to zcl_fi_carga_ativos,
  lo_bal_log type ref to zcl_bal_log.


*----------------------------------------------------------------------*
*- Tela de seleção
*----------------------------------------------------------------------*
selection-screen begin of block b01 with frame title text-t01.
parameters :
  p_file type filename75 no-display,
  p_path type filename75 lower case,
  p_test type flag as checkbox default 'X'.
selection-screen end of block b01.



*----------------------------------------------------------------------*
* Eventos
*----------------------------------------------------------------------*
initialization .

*at selection-screen on value-request for p_file .
*
*  zcl_fi_carga_ativos=>search_file(
*    changing
*      file = p_file
*  ).

at selection-screen on value-request for p_path .

  zcl_fi_carga_ativos=>server_file(
    changing
      file = p_path
  ).


start-of-selection .

  create object lo_ativos .

  if lo_ativos is bound .

    lo_ativos->get_data(
      importing
        local   = p_file
        server  = p_path
        test    = p_test
      changing
        bal_log = lo_bal_log
    ).

  endif .

end-of-selection .

  if ( lo_bal_log is bound ) and
     ( sy-batch eq abap_false ) .

    lo_bal_log->show(
      profilies = 'SINGLE_LOG'
    ).

  endif .
