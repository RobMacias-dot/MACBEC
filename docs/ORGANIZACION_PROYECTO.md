# Organización aplicada

```text
macbec_solar_app_organizado/
  ├── assets/
  │   ├── branding/
  │   │   ├── .gitkeep
  │   │   ├── logo_macbec_final.jpg
  │   │   ├── logo_macbec_final_alt.jpeg
  │   │   └── logo_macbec_original.jpg
  │   └── seeds/
  │       ├── .gitkeep
  │       ├── inversores_extractor_preview.csv
  │       └── paneles_extractor_preview.csv
  ├── docs/
  │   ├── planning/
  │   │   ├── FASE0_PLAN.md
  │   │   └── NEXT_STEPS.md
  │   └── reference/
  │       ├── catalogos/
  │       │   ├── Cables.xlsx
  │       │   └── Tuberias.xlsx
  │       ├── documentos_funcionales/
  │       │   ├── App_Cotizacion_Solar_v2.docx
  │       │   ├── App_Solar.docx
  │       │   └── App_Solar_Propuesta.pdf
  │       └── pdfs/
  │           ├── Contrato_MacBec2.pdf
  │           ├── Estacion_SJH.pdf
  │           └── recibo_cfe_15.pdf
  ├── lib/
  │   ├── app/
  │   │   ├── bootstrap/
  │   │   │   └── app_bootstrap.dart
  │   │   ├── router/
  │   │   │   ├── app_router.dart
  │   │   │   └── app_routes.dart
  │   │   ├── theme/
  │   │   │   ├── app_colors.dart
  │   │   │   └── app_theme.dart
  │   │   └── app.dart
  │   ├── core/
  │   │   ├── constants/
  │   │   │   └── app_constants.dart
  │   │   ├── errors/
  │   │   │   └── failures.dart
  │   │   ├── result/
  │   │   │   └── result.dart
  │   │   ├── security/
  │   │   │   └── session_storage.dart
  │   │   ├── utils/
  │   │   │   ├── date_time_utils.dart
  │   │   │   └── uuid_generator.dart
  │   │   └── validators/
  │   │       └── validators.dart
  │   ├── data/
  │   │   ├── files/
  │   │   │   └── file_storage_service.dart
  │   │   ├── local/
  │   │   │   └── database/
  │   │   │       ├── app_database.dart
  │   │   │       └── database_provider.dart
  │   │   └── sync/
  │   │       ├── sync_operation.dart
  │   │       └── sync_service.dart
  │   ├── features/
  │   │   ├── analisis_energetico/
  │   │   │   ├── domain/
  │   │   │   │   └── energy_analysis_rules.dart
  │   │   │   └── presentation/
  │   │   │       └── screens/
  │   │   │           └── analisis_consumo_screen.dart
  │   │   ├── auth/
  │   │   │   ├── application/
  │   │   │   │   ├── auth_controller.dart
  │   │   │   │   └── auth_state.dart
  │   │   │   ├── domain/
  │   │   │   │   └── entities/
  │   │   │   │       └── app_user.dart
  │   │   │   └── presentation/
  │   │   │       └── screens/
  │   │   │           ├── login_screen.dart
  │   │   │           ├── setup_admin_screen.dart
  │   │   │           └── splash_screen.dart
  │   │   ├── catalogo_tecnico/
  │   │   │   └── presentation/
  │   │   │       └── screens/
  │   │   │           ├── catalogo_inversores_screen.dart
  │   │   │           └── catalogo_paneles_screen.dart
  │   │   ├── clientes/
  │   │   │   ├── application/
  │   │   │   │   └── clients_controller.dart
  │   │   │   ├── data/
  │   │   │   │   └── client_repository.dart
  │   │   │   ├── domain/
  │   │   │   │   └── entities/
  │   │   │   │       └── client.dart
  │   │   │   └── presentation/
  │   │   │       └── screens/
  │   │   │           ├── cliente_detalle_screen.dart
  │   │   │           ├── cliente_form_screen.dart
  │   │   │           └── clientes_screen.dart
  │   │   ├── configuracion/
  │   │   │   └── presentation/
  │   │   │       └── screens/
  │   │   │           └── configuracion_screen.dart
  │   │   ├── cotizaciones/
  │   │   │   ├── domain/
  │   │   │   │   └── quotation_rules.dart
  │   │   │   └── presentation/
  │   │   │       └── screens/
  │   │   │           ├── cotizacion_cliente_preview_screen.dart
  │   │   │           ├── cotizacion_interna_screen.dart
  │   │   │           └── cotizacion_screen.dart
  │   │   ├── dashboard/
  │   │   │   └── presentation/
  │   │   │       └── screens/
  │   │   │           └── dashboard_screen.dart
  │   │   ├── documentos_pdf/
  │   │   │   └── infrastructure/
  │   │   │       └── pdf_service.dart
  │   │   ├── expediente/
  │   │   │   └── presentation/
  │   │   │       └── screens/
  │   │   │           └── expediente_screen.dart
  │   │   ├── firmas/
  │   │   │   └── application/
  │   │   │       └── signature_service.dart
  │   │   ├── proveedores_precios/
  │   │   │   └── presentation/
  │   │   │       └── screens/
  │   │   │           └── proveedores_screen.dart
  │   │   ├── proyectos/
  │   │   │   └── presentation/
  │   │   │       └── screens/
  │   │   │           ├── proyecto_detalle_screen.dart
  │   │   │           └── proyecto_form_screen.dart
  │   │   └── recibo_cfe/
  │   │       ├── application/
  │   │       │   └── ocr_service.dart
  │   │       └── presentation/
  │   │           └── screens/
  │   │               ├── recibo_cfe_revision_screen.dart
  │   │               └── recibo_cfe_screen.dart
  │   ├── shared/
  │   │   ├── components/
  │   │   │   └── section_card.dart
  │   │   ├── dialogs/
  │   │   │   └── app_dialogs.dart
  │   │   ├── formatters/
  │   │   │   └── currency_formatter.dart
  │   │   └── widgets/
  │   │       ├── app_scaffold.dart
  │   │       ├── empty_state.dart
  │   │       └── primary_button.dart
  │   └── main.dart
  ├── tools/
  │   └── solar_extractor/
  │       ├── archive/
  │       │   ├── extract_solar_specs_v1.py
  │       │   ├── extract_solar_specs_v2.py
  │       │   ├── extract_solar_specs_v3.py
  │       │   ├── extract_solar_specs_v4.py
  │       │   ├── extract_solar_specs_v5.py
  │       │   ├── extract_solar_specs_v6.py
  │       │   ├── extract_solar_specs_v7.py
  │       │   └── extract_solar_specs_v8.py
  │       ├── build/
  │       ├── pdfs/
  │       │   ├── ficha-tecnica-panel-solar-24v-SCL-320WP1.pdf
  │       │   ├── JA-M72D40-6002FLB_FichaTecnica.pdf
  │       │   ├── JKM600-625N-66HL4M-BDV-F1-EN.pdf
  │       │   ├── JST650-670M-132-210.pdf
  │       │   ├── MIN_7000-10000TL-X2_Hoja_de_datos_MX_20241114.pdf
  │       │   ├── SC1000-DES080628.pdf
  │       │   └── Solis_Inverter_S5-GC(124-125)K-HV_Datasheet_MEX_V1,6_202507.pdf
  │       ├── tests/
  │       │   ├── pdfs/
  │       │   │   ├── inverter_growatt_6000.pdf
  │       │   │   └── panel_jinko_550.pdf
  │       │   ├── test_inverter_basic.py
  │       │   └── test_panel_basic.py
  │       ├── extract_solar_specs.py
  │       ├── README.md
  │       └── requirements.txt
  ├── .gitignore
  ├── analysis_options.yaml
  ├── pubspec.yaml
  ├── README.md
  └── README_FASE0.md
```
