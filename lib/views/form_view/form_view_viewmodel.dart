import 'dart:io';

import 'package:frappe_app/model/common.dart';
import 'package:frappe_app/model/get_doc_response.dart';
import 'package:frappe_app/utils/loading_indicator.dart';
import 'package:injectable/injectable.dart';

import '../../app/locator.dart';
import '../../model/doctype_response.dart';
import '../../views/base_viewmodel.dart';
import '../../services/api/api.dart';

import '../../model/offline_storage.dart';
import '../../model/config.dart';
import '../../utils/enums.dart';
import '../../utils/helpers.dart';
import '../../model/queue.dart';

class FormViewViewModel extends BaseViewModel {
  late String name;
  late DoctypeDoc meta;
  late bool isDirty;

  ErrorResponse? error;
  late GetDocResponse formData;
  final user = Config().user;
  Docinfo? docinfo;
  late bool communicationOnly;

  void refresh() {
    notifyListeners();
  }

  init({
    String? doctype,
    DoctypeDoc? constMeta,
    required String constName,
  }) async {
    setState(ViewState.busy);
    communicationOnly = true;
    name = constName;
    isDirty = false;
    if (constMeta == null) {
      if (doctype != null) {
        var metaResponse = await locator<Api>().getDoctype(doctype);
        meta = metaResponse.docs[0];
      }
    } else {
      meta = constMeta;
    }
    getData();
  }

  handleFormDataChange() {
    if (!isDirty) {
      isDirty = true;
      notifyListeners();
    }
  }

  toggleSwitch(bool newVal) {
    communicationOnly = newVal;
    notifyListeners();
  }

  Future getData() async {
    setState(ViewState.busy);

    try {
      // var isOnline = await verifyOnline();
      var isOnline = true;
      var doctype = meta.name;

      if (!isOnline) {
        var response = OfflineStorage.getItem(
          '$doctype$name',
        );
        response = response["data"];
        if (response != null) {
          formData = GetDocResponse.fromJson(response);
          docinfo = formData.docinfo;
        } else {
          error = ErrorResponse(
            statusCode: HttpStatus.serviceUnavailable,
          );
        }
      } else {
        formData = await locator<Api>().getdoc(
          doctype,
          name,
        );
        docinfo = formData.docinfo;
      }
    } catch (e) {
      error = e as ErrorResponse;
    }

    setState(ViewState.idle);
  }

  getDocinfo() async {
    docinfo = await locator<Api>().getDocinfo(meta.name, name);
    notifyListeners();
  }

  Future handleUpdate({
    required Map formValue,
    required Map doc,
  }) async {
    LoadingIndicator.loadingWithBackgroundDisabled("Saving");
    // var isOnline = await verifyOnline();
    var isOnline = true;
    if (!isOnline) {
      // if (queuedData != null) {
      //   queuedData["data"] = [
      //     {
      //       ...doc,
      //       ...formValue,
      //     }
      //   ];
      //   queuedData["updated_keys"] = {
      //     ...queuedData["updated_keys"],
      //     ...extractChangedValues(
      //       doc,
      //       formValue,
      //     )
      //   };
      //   queuedData["title"] = getTitle(
      //     meta.docs[0],
      //     formValue,
      //   );

      //   Queue.putAt(
      //     queuedData["qIdx"],
      //     queuedData,
      //   );
      // } else {
      //   Queue.add(
      //     {
      //       "type": "Update",
      //       "name": name,
      //       "doctype": meta.docs[0].name,
      //       "title": getTitle(meta.docs[0], formValue),
      //       "updated_keys": extractChangedValues(doc, formValue),
      //       "data": [
      //         {
      //           ...doc,
      //           ...formValue,
      //         }
      //       ],
      //     },
      //   );
      // }
      LoadingIndicator.stopLoading();
      throw ErrorResponse(
        statusCode: HttpStatus.serviceUnavailable,
      );
    } else {
      formValue = {
        ...doc,
        ...formValue,
      };
      //Helkyds 02-05-2022;
      // TO CHECK AND REMOVE IF EMPTY
      // Check if reorder_levels [ warehouse_group,warehouse,warehouse_reorder_level,warehouse_reorder_qty,material_request_type are empty and remove
      // Check if Item_defaults: company,default_warehouse,default_price_list is empty and remove
      // Check if "customer_items":[{"customer_name":"","customer_group":"","ref_code":""}] empty and remove
      // Check if "taxes":[{"item_tax_template":"","tax_category":"","valid_from":""}]
      // Still missing to check how to pass the Price to the price list

      LogPrint("form_view_viewmodel ANTEssssss");
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
        },
      );

      late Map newformValue;
      if (toremove.isNotEmpty){
        LogPrint('toremove ');
        LogPrint(toremove);
        //newformValue = Map.fromIterable(formValue.keys.where((k) => k != toremove[0] && k != toremove[1] && k != toremove[2] && k != toremove[3]),
        //    key: (k) => k, value: (v) => formValue[v]);

        newformValue = Map.fromIterable(formValue.keys,key: (k) => k, value: (v) => formValue[v]);

        LogPrint(newformValue);
        for (var v in toremove) {
          newformValue.remove(v);
        }
        LogPrint('DEPOIS DO REMOVE.....');
        LogPrint(newformValue);

      }
      LogPrint("form_view_viewmodel DEPOOsssss");
      LogPrint(formValue);
      if (newformValue.isNotEmpty){
        formValue = newformValue;
      }

      try {
        var response = await locator<Api>().saveDocs(
          meta.name,
          formValue,
        );

        if (response.statusCode == HttpStatus.ok) {
          docinfo = Docinfo.fromJson(
            response.data["docinfo"],
          );
          formData = GetDocResponse(
            docs: response.data["docs"],
            docinfo: docinfo,
          );

          isDirty = false;

          LoadingIndicator.stopLoading();

          refresh();
        }
      } catch (e) {
        LoadingIndicator.stopLoading();
        throw e;
      }
    }
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
