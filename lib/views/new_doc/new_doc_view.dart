// @dart=2.9
import 'dart:io';

import 'package:frappe_app/model/common.dart';
import 'package:frappe_app/utils/form_helper.dart';
import 'package:frappe_app/utils/frappe_alert.dart';
import 'package:frappe_app/utils/helpers.dart';
import 'package:frappe_app/views/base_view.dart';
import 'package:frappe_app/views/new_doc/new_doc_viewmodel.dart';
import 'package:frappe_app/widgets/header_app_bar.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';

import '../../model/doctype_response.dart';

import '../../utils/enums.dart';

import '../../widgets/custom_form.dart';
import '../../widgets/frappe_button.dart';

import 'dart:developer';
import 'package:flutter/foundation.dart';

class NewDoc extends StatefulWidget {
  final DoctypeResponse meta;

  const NewDoc({
    @required this.meta,
  });

  @override
  _NewDocState createState() => _NewDocState();
}

final formHelper = FormHelper();

class _NewDocState extends State<NewDoc> {
  @override
  Widget build(BuildContext context) {
    Provider.of<ConnectivityStatus>(
      context,
    );

    return BaseView<NewDocViewModel>(
      onModelReady: (model) {
        model.meta = widget.meta;
        model.init();
      },
      builder: (context, model, child) => Builder(
        builder: (context) {
          return Scaffold(
            appBar: buildAppBar(
              title: "New ${widget.meta.docs[0].name}",
              actions: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12.0,
                    horizontal: 4,
                  ),
                  child: FrappeFlatButton(
                      buttonType: ButtonType.primary,
                      title: 'Save',
                      onPressed: () async {
                        if (formHelper.saveAndValidate()) {
                          var formValue = formHelper.getFormValue();
                          LogPrint("new_doc_view");
                          LogPrint(formValue);
                          LogPrint("widget.meta");
                          LogPrint(widget.meta);
                          LogPrint("context");
                          LogPrint(context);
                          try {
                            await model.saveDoc(
                              formValue: formValue,
                              meta: widget.meta,
                              context: context,
                            );
                          } catch (e) {
                            LogPrint(e);
                            LogPrint(e.statusMessage);
                            var _e = e as ErrorResponse;

                            if (_e.statusCode ==
                                HttpStatus.serviceUnavailable) {
                              noInternetAlert(
                                context,
                              );
                            } else {
                              //debugPrint('item: $_e.statusMessage');
                              //log('item: $_e.statusMessage');
                              FrappeAlert.errorAlert(
                                title: _e.statusMessage,
                                context: context,
                              );
                            }
                          }
                        }
                      }),
                ),
              ],
            ),
            body: CustomForm(
              formHelper: formHelper,
              doc: model.newDoc,
              fields: model.newDocFields,
            ),
          );
        },
      ),
    );
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