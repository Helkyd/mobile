import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:frappe_app/model/common.dart';
import 'package:frappe_app/model/config.dart';
import 'package:frappe_app/utils/loading_indicator.dart';
import 'package:frappe_app/utils/navigation_helper.dart';
import 'package:frappe_app/views/form_view/form_view.dart';
import 'package:injectable/injectable.dart';

import '../../app/locator.dart';
import '../../model/doctype_response.dart';
import '../../services/api/api.dart';
import '../../utils/frappe_alert.dart';
import '../../utils/helpers.dart';
import '../../model/queue.dart';
import '../../views/base_viewmodel.dart';

import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';


@lazySingleton
class NewDocViewModel extends BaseViewModel {
  late Map newDoc;
  late List<DoctypeField> newDocFields;
  late DoctypeResponse meta;

  init() {
    newDocFields = meta.docs[0].fields.where(
      (field) {
        return field.hidden != 1 && field.fieldtype != "Column Break";
      },
    ).toList();

    newDoc = {};

    newDocFields.forEach((field) {
      var defaultVal = field.defaultValue;
      if (defaultVal == '__user') {
        defaultVal = Config().userId;
      }

      if (field.fieldtype == "Table") {
        defaultVal = [];
      }
      newDoc[field.fieldname] = defaultVal;
    });
  }

  saveDoc({
    required Map formValue,
    required DoctypeResponse meta,
    required BuildContext context,
  }) async {
    LoadingIndicator.loadingWithBackgroundDisabled('Saving');

    formValue.forEach(
      (key, value) {
        if (value is Uint8List) {
          formValue[key] = "data:image/png;base64,${base64.encode(value)}";
        }
      },
    );

    var isOnline = await verifyOnline();
    if (!isOnline) {
      // var qc = Queue.getQueueContainer();
      // var queueLength = qc.length;
      // var qObj = {
      //   "type": "Create",
      //   "doctype": meta.docs[0].name,
      //   "title": hasTitle(meta.docs[0])
      //       ? formValue[meta.docs[0].titleField] ??
      //           "${meta.docs[0].name} ${queueLength + 1}"
      //       : "${meta.docs[0].name} ${queueLength + 1}",
      //   "data": [formValue],
      // };
      // Queue.add(qObj);

      // FrappeAlert.infoAlert(
      //   title: 'No Internet Connection',
      //   subtitle: 'Added to Queue',
      //   context: context,
      // );
      // Navigator.of(context).pop();
      LoadingIndicator.stopLoading();
      throw ErrorResponse(
        statusCode: HttpStatus.serviceUnavailable,
      );
    } else {
      try {
        //Helkyds 28-04-2022;
        // TO CHECK AND REMOVE IF EMPTY
        // Check if reorder_levels [ warehouse_group,warehouse,warehouse_reorder_level,warehouse_reorder_qty,material_request_type are empty and remove
        // Check if Item_defaults: company,default_warehouse,default_price_list is empty and remove
        // Check if "customer_items":[{"customer_name":"","customer_group":"","ref_code":""}] empty and remove
        // Check if "taxes":[{"item_tax_template":"","tax_category":"","valid_from":""}]
        LogPrint("ANTEssssss");
        //LogPrint(formValue);
        var toremove = [];
        formValue.forEach(
              (key, value) {

                if (key == "reorder_levels" || key == "item_defaults" || key == "customer_items" || key == "taxes"){
                  //check if empty
                  LogPrint(value[0][0]);
                  if (value[0][0] == null){
                    toremove.add(key);
                  }

                }


            if (value is Uint8List) {
              formValue[key] = "data:image/png;base64,${base64.encode(value)}";
            }
          },
        );
        if (toremove.isNotEmpty){
          LogPrint('toremove ');
          LogPrint(toremove);
          //toremove.forEach((element) {formValue.remove(element);});
          /*
          for (var v in toremove){
            LogPrint('VAI REMOVE');
            LogPrint(v);
            //formValue.remove("$v");
            formValue.remove("reorder_levels");
          }
          */
        }
        LogPrint("DEPOOsssss");
        LogPrint(formValue);

        var response = await locator<Api>().saveDocs(
          meta.docs[0].name,
          formValue,
        );
        developer.log('response: $response');

        LoadingIndicator.stopLoading();
        NavigationHelper.pushReplacement(
          context: context,
          page: FormView(
            meta: meta.docs[0],
            name: response.data["docs"][0]["name"],
          ),
        );
      } catch (e) {
        LoadingIndicator.stopLoading();
        FrappeAlert.errorAlert(
          title: (e as ErrorResponse).statusMessage,
          context: context,
        );
      }
    }
  }
  void debugPrintSynchronouslyWithText(String message,
      {int? wrapWidth}) {
    message =
    "[${DateTime.now()} ]: $message";
    debugPrintSynchronously(message, wrapWidth: wrapWidth);
  }
  static void LogPrint(Object object) async {
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
}

