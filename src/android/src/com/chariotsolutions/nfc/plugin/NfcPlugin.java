package com.chariotsolutions.nfc.plugin;

import android.app.Activity;
import android.nfc.NfcAdapter;
import android.nfc.Tag;
import android.nfc.tech.IsoDep;
import android.util.Log;

import org.apache.cordova.*;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.IOException;
import java.lang.reflect.Method;

public class NfcPlugin extends CordovaPlugin {

    private static final String TAG = "NfcPlugin";

    // actions (NAMA TIDAK DIUBAH)
    private static final String READER_MODE = "readerMode";
    private static final String DISABLE_READER_MODE = "disableReaderMode";
    private static final String CONNECT = "connect";
    private static final String TRANSCEIVE = "transceive";
    private static final String CLOSE = "close";
    private static final String ENABLED = "enabled"; // ✅ BARU

    // status
    private static final String STATUS_NFC_OK = "NFC_OK"; // ✅ BARU
    private static final String STATUS_NFC_DISABLED = "NFC_DISABLED"; // optional

    private CallbackContext readerModeCallback;
    private IsoDep isoDep;

    // ===================== EXECUTE =====================
    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
        if (ENABLED.equalsIgnoreCase(action)) {
            NfcAdapter adapter = NfcAdapter.getDefaultAdapter(getActivity());

            if (adapter != null && adapter.isEnabled()) {
                callbackContext.success(STATUS_NFC_OK);
            } else {
                callbackContext.error(STATUS_NFC_DISABLED);
            }
            return true;
        }

        if (READER_MODE.equalsIgnoreCase(action)) {
            int flags = args.getInt(0);
            enableReaderMode(flags, callbackContext);
            return true;
        }

        if (DISABLE_READER_MODE.equalsIgnoreCase(action)) {
            disableReaderMode(callbackContext);
            return true;
        }

        if (CONNECT.equalsIgnoreCase(action)) {
            connect(callbackContext);
            return true;
        }

        if (TRANSCEIVE.equalsIgnoreCase(action)) {
            JSONArray data = args.getJSONArray(0);
            byte[] command = Util.jsonToByteArray(data);
            transceive(command, callbackContext);
            return true;
        }

        if (CLOSE.equalsIgnoreCase(action)) {
            close(callbackContext);
            return true;
        }

        return false;
    }

    // ===================== READER MODE =====================
    private void enableReaderMode(int flags, CallbackContext callbackContext) {
        readerModeCallback = callbackContext;

        cordova.getActivity().runOnUiThread(() -> {
            NfcAdapter adapter = NfcAdapter.getDefaultAdapter(getActivity());
            adapter.enableReaderMode(
                getActivity(),
                readerCallback,
                flags,
                null
            );
        });
    }

    private void disableReaderMode(CallbackContext callbackContext) {
        cordova.getActivity().runOnUiThread(() -> {
            NfcAdapter adapter = NfcAdapter.getDefaultAdapter(getActivity());
            adapter.disableReaderMode(getActivity());
            callbackContext.success();
        });
    }

    // ===================== NFC LISTENER =====================
    private final NfcAdapter.ReaderCallback readerCallback = new NfcAdapter.ReaderCallback() {
        @Override
        public void onTagDiscovered(Tag tag) {
            lastTag = tag; // <<< WAJIB BIAR IsoDep CONNECT BISA
            try {
                JSONObject json = new JSONObject();
                json.put("id", Util.byteArrayToJSON(tag.getId()));
                json.put("techList", new JSONArray(tag.getTechList()));

                PluginResult result = new PluginResult(PluginResult.Status.OK, json);
                result.setKeepCallback(true);

                if (readerModeCallback != null) {
                    readerModeCallback.sendPluginResult(result);
                }

            } catch (Exception e) {
                Log.e(TAG, "onTagDiscovered error", e);
            }
        }
    };

    // ===================== CONNECT ISO-DEP =====================
    private void connect(CallbackContext callbackContext) {
        cordova.getThreadPool().execute(() -> {
            try {
                Tag tag = getLastTag();
                if (tag == null) {
                    callbackContext.error("No tag");
                    return;
                }

                isoDep = IsoDep.get(tag);
                if (isoDep == null) {
                    callbackContext.error("IsoDep not supported");
                    return;
                }

                isoDep.connect();

                JSONObject result = new JSONObject();
                result.put("maxTransceiveLength", isoDep.getMaxTransceiveLength());
                callbackContext.success(result);

            } catch (Exception e) {
                callbackContext.error(e.getMessage());
            }
        });
    }

    // ===================== TRANSCEIVE =====================
    private void transceive(byte[] command, CallbackContext callbackContext) {
        cordova.getThreadPool().execute(() -> {
            try {
                if (isoDep == null || !isoDep.isConnected()) {
                    callbackContext.error("IsoDep not connected");
                    return;
                }

                byte[] response = isoDep.transceive(command);
                callbackContext.success(response);

            } catch (IOException e) {
                callbackContext.error(e.getMessage());
            }
        });
    }

    // ===================== CLOSE =====================
    private void close(CallbackContext callbackContext) {
        cordova.getThreadPool().execute(() -> {
            try {
                if (isoDep != null && isoDep.isConnected()) {
                    isoDep.close();
                }
                isoDep = null;
                callbackContext.success();
            } catch (IOException e) {
                callbackContext.error(e.getMessage());
            }
        });
    }

    // ===================== HELPERS =====================
    private Tag lastTag;

    private Tag getLastTag() {
        return lastTag;
    }

    private Activity getActivity() {
        return cordova.getActivity();
    }
}
