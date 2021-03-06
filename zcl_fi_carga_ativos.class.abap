class zcl_fi_carga_ativos definition
  public
  final
  create public .


  public section.

    class-methods search_file
      changing
        !file type filename75 .

    class-methods server_file
      changing
        !file type filename75 .

    methods get_data
      exporting
        !local   type filename75
        !server  type filename75
        !test    type flag
      changing
        !bal_log type ref to zcl_bal_log .

    methods progress
      importing
        percent type i
        text    type char40 .

  protected section.

  private section.

    types:
      bapi1022_cumval_t     type standard table of bapi1022_cumval
                            with default key,
      bapi1022_dep_areas_t  type standard table of bapi1022_dep_areas
                            with default key,
      bapi1022_dep_areasx_t type standard table of bapi1022_dep_areasx
                            with default key .

    methods check_files
      exporting
        !local   type filename75
        !server  type filename75
      changing
        !bal_log type ref to zcl_bal_log
        !error   type flag .

    methods import_data
      exporting
        !data_tab type zfis0003_t
        !local    type filename75
        !server   type filename75
      changing
        !bal_log  type ref to zcl_bal_log .

    methods process_data
      importing
        !test     type flag
      changing
        !bal_log  type ref to zcl_bal_log
        !data_tab type zfis0003_t .

    methods upload_local
      importing
        filename type string
      exporting
        data     type truxs_t_text_data
      changing
        !bal_log type ref to zcl_bal_log .

    methods upload_server
      importing
        filename type string
      exporting
        data     type truxs_t_text_data
      changing
        !bal_log type ref to zcl_bal_log .

    methods post_data
      importing
        !test                type flag
        !key                 type bapi1022_key
        !generaldata         type bapi1022_feglg001
        !generaldatax        type bapi1022_feglg001x
        !postinginformation  type bapi1022_feglg002
        !postinginformationx type bapi1022_feglg002x
        !timedependentdata   type bapi1022_feglg003
        !timedependentdatax  type bapi1022_feglg003x
        !depreciationareas   type bapi1022_dep_areas_t optional
        !depreciationareasx  type bapi1022_dep_areasx_t optional
        !cumulatedvalues     type bapi1022_cumval_t optional
      changing
        !bal_log             type ref to zcl_bal_log .

    methods format_number
      changing
        !number type any .

    methods format_date
      changing
        !date type char12 .

    methods format_numc
      changing
        !numc type any .

    methods format_assetclass
      changing
        !assetclass type char8 .

    methods format_area
      changing
        !area type numc2 .

    methods progress_prepare
      importing
        !tabix  type sytabix
        !lines  type i
      exporting
        msg     type char40
        percent type i .

    methods add_40
      changing
        !data_tab type zfis0003_t .

endclass.



class zcl_fi_carga_ativos implementation.


  method get_data.

    data:
      identif  type balnrext,
      data_tab type zfis0003_t,
      error    type flag.

    concatenate sy-cprog sy-datum sy-uzeit
           into identif
      separated by abap_undefined .

*   Criando objeto para Controle de Log/Mensagem
    if bal_log is not bound .
      create object bal_log
        exporting
          identif   = identif
          object    = 'ZFI'
          subobject = 'ZFI0002'
          alprog    = sy-cprog.
    endif .

    if ( sy-batch eq abap_true ) and
       ( sy-uname eq 'ABAP00' ) .

*      do .
*      enddo .

    endif .

    me->check_files(
      importing
        local   = local
        server  = server
      changing
        bal_log = bal_log
        error   = error
    ).


    if error eq abap_false .

      me->import_data(
        importing
          data_tab = data_tab
          local    = local
          server   = server
        changing
          bal_log  = bal_log
        ).

      me->process_data(
        exporting
          test     = test
        changing
          bal_log  = bal_log
          data_tab = data_tab
      ).

    endif .

  endmethod.

  method search_file.


    data:
      lt_filetable type filetable,
      lv_rc        type i.

    call method cl_gui_frontend_services=>file_open_dialog
      exporting
*       window_title            =
        default_extension       = 'csv'
*       default_filename        =
        file_filter             = 'CSV files (*.csv)|*.csv'
*       with_encoding           =
*       initial_directory       =
*       multiselection          =
      changing
        file_table              = lt_filetable
        rc                      = lv_rc
*       user_action             =
*       file_encoding           =
      exceptions
        file_open_dialog_failed = 1
        cntl_error              = 2
        error_no_gui            = 3
        not_supported_by_gui    = 4
        others                  = 5.
    if sy-subrc eq 0 .
      read table lt_filetable into data(ls_filetable)
       index 1 .
      if sy-subrc eq 0 .
        file = ls_filetable-filename .
      endif .
    else .
      message id sy-msgid type sy-msgty number sy-msgno
            with sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    endif.


  endmethod.

  method server_file .

    data:
      dxlpath type dxlpath .

    call function 'F4_DXFILENAME_TOPRECURSION'
      exporting
*       i_location_flag = ' '    " Flag: Application or presentation server
*       i_server       = '?'    " Application Server
        i_path         = '/usr/sap/trans/'
*       filemask       = '*.*'
*       fileoperation  = 'R'
      importing
*       o_location_flag =
*       o_server       =
        o_path         = dxlpath
*       abend_flag     =
      exceptions
        rfc_error      = 1
        error_with_gui = 2
        others         = 3.

    if sy-subrc eq 0 .

      file = dxlpath .

    else .

      message id sy-msgid type sy-msgty number sy-msgno
            with sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.

    endif.


  endmethod .

  method process_data.

    data: data_aux             type zfis0003_t,
          cumulatedvalues_t    type bapi1022_cumval_t,
          depreciationareas_t  type bapi1022_dep_areas_t,
          depreciationareasx_t type bapi1022_dep_areasx_t,
          message              type char40,
          percent              type i,
          tabix                type char10,
          msgv4                type symsgv.

    append lines of data_tab to data_aux .
    delete adjacent duplicates from data_aux comparing identificador .

    sort data_tab ascending by identificador .

    data(lines) = lines( data_aux ) .

    loop at data_aux into data(line_aux) .

      me->progress_prepare(
        exporting
          tabix   = sy-tabix
          lines   = lines
        importing
          msg     = message
          percent = percent
      ).

      me->progress(
        exporting
          percent = percent
          text    = message
      ).

      data(conta) = lines - sy-tabix .

      read table data_tab transporting no fields
        with key identificador = line_aux-identificador
        binary search .

      if sy-subrc eq 0 .

*       Campos de chave na criação
        data(key) = value bapi1022_key( companycode = line_aux-companycode ) .

*       Grupos de campo lógicos 001 - dados gerais
        data(generaldata) = value bapi1022_feglg001( assetclass = line_aux-assetclass
                                                     descript   = line_aux-descript
                                                     descript2  = line_aux-descript2
                                                     serial_no  = line_aux-serial_no
*                                                    quantity   = line_aux-quantity
*                                                    base_uom   = line_aux-base_uom
                                                     ) .

        data(generaldatax) = value bapi1022_feglg001x( descript  = abap_on
                                                       descript2 = abap_on
                                                       serial_no = abap_on
*                                                      quantity  = abap_on
*                                                      base_uom  = abap_on
                                                       ) .

*       Grupos de campo lógicos 002 -  infos.lançamento
        data(postinginformation)  = value bapi1022_feglg002( cap_date = line_aux-cap_date ) .

        data(postinginformationx) = value bapi1022_feglg002x( cap_date = abap_on ) .

*       Grupos de campo lógicos 003 - dados dependentes de tempo
        data(timedependentdata) = value bapi1022_feglg003( costcenter = line_aux-costcenter
                                                           plant      = line_aux-plant
                                                           location   = line_aux-location ) .

        data(timedependentdatax) = value bapi1022_feglg003x( costcenter = abap_on
                                                             plant      = abap_on
                                                             location   = abap_on ) .

        loop at data_tab into data(line) from sy-tabix .

          if line-identificador eq line_aux-identificador .
          else .
            exit .
          endif .

*         Área de avaliação (todos grupos de campo lógicos)
          data(depreciationareas) =
            value bapi1022_dep_areas( area      = line-area
                                      ulife_yrs = line-ulife_yrs ) .

          append depreciationareas to depreciationareas_t .
          clear  depreciationareas .

          data(depreciationareasx) =
            value bapi1022_dep_areasx( area      = line-area
                                       ulife_yrs = abap_on ).

          append depreciationareasx to depreciationareasx_t .
          clear  depreciationareasx .

*         Grupo de campos lógico CUMVAL: valores transferência acumul.
          data(cumulatedvalues) =
            value bapi1022_cumval( area      = line-area
                                   acq_value = line-acq_value
                                   ord_dep   = line-ord_dep ) .

          append cumulatedvalues to cumulatedvalues_t .
          clear  cumulatedvalues .

        endloop.

        if bal_log is bound .

          concatenate line_aux-assetclass '/' line_aux-descript
                 into msgv4 .

          data(msg) =
            value bal_s_msg(
              msgty = ''
              msgno = 000
              msgid = 'ZFI'
              msgv1 = 'Documento'
              msgv2 = line_aux-identificador
              msgv3 = '-'
              msgv4 = msgv4
              ).

          bal_log->add( msg = msg ).

        endif .

*       Salvar Ativo
        me->post_data(
          exporting
            test                = test
            key                 = key
            generaldata         = generaldata
            generaldatax        = generaldatax
            postinginformation  = postinginformation
            postinginformationx = postinginformationx
            timedependentdata   = timedependentdata
            timedependentdatax  = timedependentdatax
            depreciationareas   = depreciationareas_t
            depreciationareasx  = depreciationareasx_t
            cumulatedvalues     = cumulatedvalues_t
          changing
            bal_log             = bal_log
        ).

        clear: key, generaldata, generaldatax, postinginformation, postinginformationx,
               timedependentdata, timedependentdatax, depreciationareas_t,
               depreciationareasx_t ,cumulatedvalues, cumulatedvalues_t .

      endif .

    endloop .

  endmethod.


  method check_files .


    if sy-batch eq abap_true .

      if server is initial .

        data(ls_msg) =
          value bal_s_msg( msgty = 'E'
                           msgno = 000
                           msgid = 'ZFI'
                           msgv1 = 'Arquivo do servidor inválido.'
                           msgv2 = 'Favor verificar.'  ) .

        bal_log->add( msg = ls_msg ).

        error = abap_on .

      endif .

    endif .


    if ( server is initial ) and
       ( local  is initial ) and
       ( error  eq abap_false ) .

      ls_msg =
        value #( msgty = 'E'
                 msgno = 000
                 msgid = 'ZFI'
                 msgv1 = 'Arquivo(s) do servidor inválido(s).'
                 msgv2 = 'Favor verificar.'  ) .

      bal_log->add( msg = ls_msg ).
      error = abap_on .

    endif .

  endmethod .


  method import_data.

    data: filename    type string,
          data_import type truxs_t_text_data,
          line        type zfis0003,
          quantity    type char10,
          cap_date    type char12,
          acq_value   type char20,
          ord_dep     type char20,
          final       type char50.

    me->progress(
      exporting
        percent = 10
        text    = 'Importando informações...'
    ).


    if server is not initial .

      filename = server .

      me->upload_server(
        exporting
          filename = filename
        importing
          data     = data_import
        changing
          bal_log  = bal_log
      ).

    else .

      if local is not initial .

        filename = local .

        me->upload_local(
          exporting
            filename = filename
          importing
            data     = data_import
          changing
            bal_log  = bal_log
        ).

      endif .

    endif .

    if lines( data_import ) eq 0 .

      data(ls_msg) =
        value bal_s_msg( msgty = 'E'
                         msgno = 000
                         msgid = 'ZFI'
                         msgv1 = 'Falha ao carregar informações.'
                         msgv2 = 'Arquivo inválido.' ) .

      bal_log->add( exporting msg = ls_msg ).


    else .

      delete data_import index 1 .

      loop at data_import into data(line_import).

        split line_import at ';'
                  into line-identificador
                       line-assetclass
                       line-companycode
                       line-descript
                       line-descript2
                       line-serial_no
                       quantity       " line-quantity
                       line-base_uom
                       cap_date       " line-cap_date
                       line-costcenter
                       line-plant
                       line-location
                       line-area
                       line-ulife_yrs
                       acq_value      " line-acq_value .
                       ord_dep        " line-ord_dep .
                       final .

        me->format_numc( changing numc = line-identificador ) .
        me->format_assetclass( changing assetclass = line-assetclass ).
        me->format_date( changing date = cap_date ).
        me->format_area( changing area = line-area ).
        me->format_numc( changing numc = line-ulife_yrs ) .
        me->format_number( changing number = acq_value ) .
        me->format_number( changing number = ord_dep ) .
        concatenate ord_dep '-' into ord_dep .

        data(data_line) =
          value zfis0003( identificador = conv oij02_index( line-identificador )
                          companycode   = line-companycode
                          assetclass    = line-assetclass
                          descript      = line-descript
                          descript2     = line-descript2
                          serial_no     = line-serial_no
*                         quantity      = conv menge_d( menge )
*                         base_uom      = line-base_uom
                          cap_date      = cap_date
                          costcenter    = line-costcenter
                          plant         = line-plant
                          location      = line-location
                          area          = line-area
                          ulife_yrs     = conv bf_ndjar( line-ulife_yrs )
                          acq_value     = conv bf_kansw( acq_value )
                          ord_dep       = conv bf_knafa( ord_dep )
                        ) .

        append data_line to data_tab .
        clear  data_line .

      endloop .

    endif.


*    me->add_40(
*      changing
*        data_tab = data_tab
*    ).

  endmethod.


  method upload_local .

    data:
      ls_msg type bal_s_msg .

    refresh data .

    call function 'GUI_UPLOAD'
      exporting
        filename                = filename
*       filetype                = 'asc'
*       has_field_separator     = ' '
*       header_length           = 0
*       read_by_line            = 'x'
*       dat_mode                = ' '
*       codepage                = ' '
*       ignore_cerr             = abap_true
*       replacement             = '#'
*       check_bom               = ' '
*       virus_scan_profile      =
*       no_auth_check           = ' '
*       importing
*       filelength              =
*       header                  =
      tables
        data_tab                = data
*       changing
*       isscanperformed         = ' '
      exceptions
        file_open_error         = 1
        file_read_error         = 2
        no_batch                = 3
        gui_refuse_filetransfer = 4
        invalid_type            = 5
        no_authority            = 6
        unknown_error           = 7
        bad_data_format         = 8
        header_not_allowed      = 9
        separator_not_allowed   = 10
        header_too_long         = 11
        unknown_dp_error        = 12
        access_denied           = 13
        dp_out_of_memory        = 14
        disk_full               = 15
        dp_timeout              = 16
        others                  = 17.

    if sy-subrc eq 0 .

    else .

      if bal_log is bound .

        bal_log->syst_to_ballog(
          exporting
            syst      = sy
          importing
            bal_s_msg = ls_msg
        ).

        bal_log->add( exporting msg = ls_msg ).

      endif .

    endif .

  endmethod .


  method upload_server .

    data:
      line type line of truxs_t_text_data,
      file type string.

    refresh data .

    file = filename .

    open dataset file for input in legacy text mode with windows linefeed .

    if sy-subrc eq 0.

      do.

        clear: line .

        read dataset file into line .

        if sy-subrc eq 0 .

          append line to data .

        else.

          exit.

        endif.

      enddo.

      close dataset file .

      if lines( data ) eq 0 .

        data(ls_msg) =
          value bal_s_msg( msgty = 'E'
                           msgno = 000
                           msgid = 'ZFI'
                           msgv1 = 'Error writing File.'
                         ) .

        bal_log->add( msg = ls_msg ).

        exit .

      endif.

    else.

      ls_msg =
        value #( msgty = 'E'
                 msgno = 000
                 msgid = 'ZFI'
                 msgv1 = 'File not found.'
               ) .

      bal_log->add( msg = ls_msg ).

      exit .

    endif.


  endmethod .


  method format_number.

    if number is not initial .

      translate number using '. ' .
      condense number no-gaps .
      translate number using ',.' .

      if number eq '-' .
        number = '0' .
      endif .

    endif .



  endmethod.


  method format_date.

    if date is not initial .

      translate date using '/.' .

      call function 'CONVERSION_EXIT_PDATE_INPUT'
        exporting
          input        = date
        importing
          output       = date
        exceptions
          invalid_date = 1
          others       = 2.
      if sy-subrc eq 0 .
      else .
        message id sy-msgid type sy-msgty number sy-msgno
                   with sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
      endif.

    endif .

  endmethod.



  method post_data.

    data:
      return  type standard table of bapiret2,
      message type bal_s_msg.

    call function 'BAPI_FIXEDASSET_OVRTAKE_CREATE'
      exporting
        key                 = key    " Key of Asset Being Created
*       reference           =     " Reference for Creating Using Reference
*       createsubnumber     =     " Create Asset Subnumber?
*       creategroupasset    =     " Indicator: Asset is a group asset
        testrun             = test
        generaldata         = generaldata
        generaldatax        = generaldatax
*       inventory           =     " Inventory
*       inventoryx          =     " Change Parameters for Inventory
        postinginformation  = postinginformation
        postinginformationx = postinginformationx
        timedependentdata   = timedependentdata
        timedependentdatax  = timedependentdatax
*       allocations         =     " Allocations
*       allocationsx        =     " Change Parameters for Allocations
*       origin              =     " Origin
*       originx             =     " Change Parameters for Origin
*       investacctassignmnt =     " Account Assignment for Investment
*       investacctassignmntx =     " Change Parameters for Investment Account Assignments
*       networthvaluation   =     " Net worth valuation
*       networthvaluationx  =     " Change Parameters for Net Worth Valuation
*       realestate          =     " Real Estate and Similar Rights
*       realestatex         =     " Change Parameters for Real Estate
*       insurance           =     " Insurance
*       insurancex          =     " Change Parameters for Insurance
*       leasing             =     " Leasing
*       leasingx            =     " Change Parameters for Leasing
*       glo_rus_gen         =     " Russia - General Data (Time-Independent)
*       glo_rus_genx        =     " Change Parameters: Russia - General Data (Time-Independent)
*       glo_rus_ptx         =     " Russia - Time-Independent Data - Net Worth Tax
*       glo_rus_ptxx        =     " Change Parameters: Russia - Time-Independent Data - Net Wort
*       glo_rus_ttx         =     " Russia - Time-Independent Data - Transport Tax
*       glo_rus_ttxx        =     " Change Parameters: Russia - Time-Independent Data - Transpor
*       glo_in_gen          =     " India - Time-Independent General Data (BAPI-struc.)
*       glo_in_genx         =     " Update Flags: India - Time-Independent General Data (BAPI-st
*       glo_jp_ann16        =     " Japan - Time-Independent Data for Annex 16
*       glo_jp_ann16x       =     " Update Flags: Japan - Time-Independent Data for Annex 16
*       glo_jp_ptx          =     " Japan - Time-Independent Data for Property Tax
*       glo_jp_ptxx         =     " Update Flags: Japan - Time-Independent Data for Property Tax
*       glo_time_dep        =     " Globalization Fields: Date Interval of Time-Dependent Data
*       glo_rus_gentd       =     " Russia - General Data (Time-Dependent)
*       glo_rus_gentdx      =     " Change Parameters: Russia - General Data (Time-Dependent)
*       glo_rus_ptxtd       =     " Russia - Time-Dependent Data - Net Worth Tax
*       glo_rus_ptxtdx      =     " Change Parameters: Russia - Time-Dependent Data - Net Worth
*       glo_rus_ttxtd       =     " Russia - Time-Dependent Data - Transport Tax
*       glo_rus_ttxtdx      =     " Change Parameters: Russia - Time-Dependent Data - Transport
*       glo_jp_imptd        =     " Japan - Time-Dependent Impairment Data (BAPI)
*       glo_jp_imptdx       =     " Update Flags: Japan - Time Dependent Impairment Data (BAPI)
*      importing
*       companycode         =     " Company Code of Asset Created
*       asset               =     " Main Number of Asset Created
*       subnumber           =     " Subnumber of Created Asset
*       assetcreated        =     " Asset Created
      tables
        depreciationareas   = depreciationareas
        depreciationareasx  = depreciationareasx
*       investment_support  =     " Investment Support Key
*       extensionin         =     " Customer Enhancements
        cumulatedvalues     = cumulatedvalues
*       postedvalues        =     " Posted values
*       transactions        =     " Transactions for Transfer during Fiscal Year
*       proportionalvalues  =     " Proportional Values on Transactions
        return              = return    " BAPI Return Table
*       postingheaders      =     " Header Info for Postings During Year - Legacy Data Transfer
      .

    if test is not initial .
    else .
      read table return transporting no fields
        with key type = 'E' .
      if sy-subrc eq 0 .
        call function 'BAPI_TRANSACTION_ROLLBACK'
*        importing
*          return =     " Return Messages
          .
      else .
        call function 'BAPI_TRANSACTION_COMMIT'
*        exporting
*          wait   =     " Use of Command `COMMIT AND WAIT`
*        importing
*          return =     " Return Messages
          .
      endif .
    endif .

    if return[] is not initial .

      loop at return into data(line) .

        try .
            call function 'EHPRC_CP_LB03N_MAP_BAPIRET2'
              exporting
                is_message = line
*               it_message = return
              importing
                es_message = message.
*               et_message = return_bal_log.
          catch cx_root into data(error) .

        endtry.

        if ( message is not initial ) and
           ( bal_log is bound ) .
          bal_log->add( msg = message ).
        endif .

      endloop .

    endif .

  endmethod.

  method format_numc .

    if numc is not initial .

      call function 'CONVERSION_EXIT_ALPHA_INPUT'
        exporting
          input  = numc
        importing
          output = numc.

    endif .

  endmethod.

  method format_assetclass.

    data asset type bf_anlkl .

    if assetclass is not initial .

      call function 'CONVERSION_EXIT_ALPHA_INPUT'
        exporting
          input  = assetclass
        importing
          output = asset.

      assetclass = asset .

    endif .

  endmethod.

  method format_area .

    data area_converet type numc2 .

    if area is not initial .

      call function 'CONVERSION_EXIT_ALPHA_INPUT'
        exporting
          input  = area
        importing
          output = area_converet.

      area = area_converet .

    endif .

  endmethod.

  method progress_prepare .

    data:
      lines_char type char20,
      tabix_char type char20,
      calc       type i.

    lines_char = lines .
    tabix_char = sy-tabix .

**   Diferença
*    calc = lines - sy-tabix .
*
**   Percentagem = Diferença / Total
*    calc = calc / lines .
*
**   Passando para Valor Inteiro
*    percent = trunc( calc * 100 ) .
*    percent = 100 - percent .

    condense:
      lines_char no-gaps,
      tabix_char no-gaps .

*    write percent to msg .
*    condense msg no-gaps .
*    concatenate msg '%' 'processado...'
*           into msg separated by space .

    concatenate tabix_char
                '/'
                lines_char
                'processando...'
           into msg
      separated by space .

  endmethod .

  method add_40 .

    data:
      data_aux type zfis0003_t .

    sort data_tab by identificador ascending .
    append lines of data_tab to data_aux .

    delete adjacent duplicates from data_aux
    comparing identificador .

    loop at data_aux into data(line_aux) .

      data(proximo) = sy-tabix + 1 .

      read table data_tab transporting no fields
        with key identificador = line_aux-identificador
                 area          = 40 .
      if sy-subrc eq 0 .

      else .

        line_aux-area = 40 .
        line_aux-acq_value = '0.1' .
        line_aux-ord_dep = '0.1-' .

        read table data_aux transporting identificador
              into data(identificador)
              index proximo .

        if sy-subrc eq 0 .

          read table data_tab transporting no fields
            with key identificador = identificador-identificador .

          if sy-subrc eq 0 .

            insert line_aux into data_tab index sy-tabix .

          endif .

        else .

          append line_aux to data_tab .

        endif .

        clear line_aux .

      endif .

    endloop.

  endmethod .


  method progress .

    if text is not initial .

      call function 'SAPGUI_PROGRESS_INDICATOR'
        exporting
          percentage = percent
          text       = text.

    endif .

  endmethod .

endclass.
