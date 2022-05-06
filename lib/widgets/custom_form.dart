import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:frappe_app/app/locator.dart';
import 'package:frappe_app/form/controls/control.dart';
import 'package:frappe_app/model/common.dart';
import 'package:frappe_app/model/doctype_response.dart';
import 'package:frappe_app/services/api/api.dart';
import 'package:frappe_app/utils/form_helper.dart';
import 'package:frappe_app/utils/helpers.dart';
import 'package:frappe_app/views/base_viewmodel.dart';
import 'package:frappe_app/views/base_widget.dart';

class CustomForm extends StatelessWidget {
  final FormHelper formHelper;
  final List<DoctypeField> fields;
  final Map doc;
  final void Function()? onChanged;

  const CustomForm({
    required this.formHelper,
    required this.fields,
    required this.doc,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return BaseWidget<CustomFormViewModel>(
      onModelReady: (model) {
        model.doc = doc;
        model.fields = fields;
        model.handleDependsOn();
      },
      model: CustomFormViewModel(),
      builder: (context, model, child) => FormBuilder(
        onChanged: () {
          LogPrint('custom_form - OnChanged');
          LogPrint(formHelper.getFormValue());

          formHelper.save();
          model.handleFormDataChange(formHelper.getFormValue());

          if (onChanged != null) {
            onChanged!();
          }
        },
        autovalidateMode: AutovalidateMode.onUserInteraction,
        key: formHelper.getKey(),
        child: SingleChildScrollView(
          child: Column(
            children: generateLayout(
              fields: fields,
              doc: model.doc,
              onControlChanged: (
                fieldValue,
              ) {
                LogPrint('custom_form - OncontrolChanged');
                LogPrint(fieldValue);
                LogPrint(formHelper);
                LogPrint(fields);

                model.handleFetchFrom(
                  fieldValue: fieldValue,
                  formHelper: formHelper,
                  fields: fields,
                );

                model.handleDependsOn();
              },
            ),
          ),
        ),
      ),
    );
  }
}

class CustomFormViewModel extends BaseViewModel {
  late Map doc;
  late List<DoctypeField> fields;

  handleFormDataChange(Map formValue) {
    doc = {
      ...formValue,
    };
    notifyListeners();
  }

  handleDependsOn() {
    LogPrint('custom_form - handleDependsOn');
    var formValEncoded = jsonEncode(doc);
    var dependsOnFields = fields
        .where(
          (field) =>
              field.dependsOn != null || field.mandatoryDependsOn != null,
        )
        .toList();
    dependsOnFields.forEach(
      (field) {
        LogPrint('dependsOnFields');
        LogPrint(field.fieldname);
        if (field.dependsOn != null) {
          if (field.dependsOn!.startsWith("eval")) {
            var dependsOnDocProperty = field.dependsOn!.split("eval:")[1];
            var dependsOnEvalResult = executeJS(jsString: """
            var doc = $formValEncoded;
            $dependsOnDocProperty
            """);

            if (dependsOnEvalResult == 1 || dependsOnEvalResult == true) {
              field.pVisible = 1;
            } else {
              field.pVisible = 0;
            }
          } else {
            var dependsOnVal = doc[field.dependsOn];
            if (dependsOnVal is String) {
              if (dependsOnVal.isEmpty) {
                field.pVisible = 0;
              } else {
                if (dependsOnVal == "1") {
                  field.pVisible = 1;
                } else if (dependsOnVal == "0") {
                  field.pVisible = 0;
                } else {
                  field.pVisible = 1;
                }
              }
            } else if (doc[field.dependsOn] is List) {
              field.pVisible = doc[field.dependsOn].isEmpty ? 0 : 1;
            } else {
              // always visible if handling of type is missing
              field.pVisible = 1;
            }
          }
        }

        if (field.mandatoryDependsOn != null) {
          if (field.mandatoryDependsOn!.startsWith("eval")) {
            var mandatoryDependsOnDocProperty =
                field.mandatoryDependsOn!.split("eval:")[1];
            var mandatoryDependsOnEvalResult = executeJS(jsString: """
            var doc = $formValEncoded;
            $mandatoryDependsOnDocProperty
            """);
            if (mandatoryDependsOnEvalResult == 1 ||
                mandatoryDependsOnEvalResult == true) {
              field.reqd = 1;
            } else {
              field.reqd = 0;
            }
          } else {
            field.reqd = doc[field.mandatoryDependsOn] is String
                ? int.parse(doc[field.mandatoryDependsOn])
                : doc[field.mandatoryDependsOn];
          }
        }
      },
    );
  }

  handleFetchFrom({
    required FieldValue fieldValue,
    required FormHelper formHelper,
    required List<DoctypeField> fields,
  }) async {
    LogPrint('custom_form - handleFetchFrom');
    var dependentFields = fields
        .where(
          (element) =>
              element.fetchFrom != null &&
              element.fetchFrom!.split('.')[0] == fieldValue.field.fieldname,
        )
        .toList();

    var fetchFromFields = dependentFields
        .map((e) => {
              "fetch_from_field": e.fetchFrom!.split(".")[1],
              "fieldname": e.fieldname,
            })
        .toList();

    if (fetchFromFields.isNotEmpty) {
      LogPrint('fetchfromfields isNOTEMPTY');
      try {
        var fetchFromVal = await locator<Api>().getdoc(
          fieldValue.field.options,
          fieldValue.value.toString(),
        );
        LogPrint('fetchfromfields');
        LogPrint(fetchFromVal.docs[0]);

        var fetchDoc = fetchFromVal.docs[0];
        Map<String, dynamic> fetchDoc1 = {};
        fetchFromFields.forEach(
          (element) {
            var v;
            // TODO use meta
            if (fetchDoc[element["fetch_from_field"]] == 1) {
              v = true;
            } else if (fetchDoc[element["fetch_from_field"]] == 0) {
              v = false;
            } else {
              v = fetchDoc[element["fetch_from_field"]].toString();
            }
            fetchDoc1[element["fieldname"] as String] = v;
          },
        );
        LogPrint('fetchDoc1');
        LogPrint(fetchDoc1);

        formHelper.updateValues(fetchDoc1);
      } catch (e) {
        print(e.toString());
      }
    }
  }
}

void LogPrint(Object object) async {
  int defaultPrintLength = 1020;
  if (object == null || object.toString().length <= defaultPrintLength) {
    print(object);
  } else {
    String log = object.toString();
    int start = 0;
    int endIndex = defaultPrintLength;
    int logLength = log.length;
    int tmpLogLength = log.length;
    while (endIndex < logLength) {
      print(log.substring(start, endIndex));
      endIndex += defaultPrintLength;
      start += defaultPrintLength;
      tmpLogLength -= defaultPrintLength;
    }
    if (tmpLogLength > 0) {
      print(log.substring(start, logLength));
    }
  }
}