package com.chariotsolutions.nfc.plugin;

import android.app.Activity;
import android.nfc.NfcAdapter;
import android.nfc.Tag;
import android.nfc.tech.IsoDep;
import android.os.Bundle;
import android.util.Log;

import org.apache.cordova.*;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.Arrays;

public class NfcPlugin extends CordovaPlugin {

    private static final String TAG = "NfcPlugin";

    private static final String READER_MODE = "readerMode";
    private static final String DISABLE_READER_MODE = "disableReaderMode";
    private static final String CONNECT = "connect";
    private static final String TRANSCEIVE = "transceive";
    private static final String CLOSE = "close";
    private static final String ENABLED = "enabled";

    private static final String STATUS_NFC_OK = "NFC_OK";
    private static final String STATUS_NFC_DISABLED = "NFC_DISABLED";

    private CallbackContext readerModeCallback;
    private IsoDep isoDep;
    private Tag lastTag;

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
        Log.e(TAG, "execute() action=" + action);

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
            readerMode(flags, callbackContext);
            return true;
        }

        if (DISABLE_READER_MODE.equalsIgnoreCase(action)) {
            disableReaderMode(callbackContext);
            return true;
        }

        if (CONNECT.equalsIgnoreCase(action)) {
            connect(args, callbackContext);
            return true;
        }

        if (TRANSCEIVE.equalsIgnoreCase(action)) {
            ordovaArgs args = new CordovaArgs(data);

            byte[] command;
            try {
                command = args.getArrayBuffer(0); // langsung dapet byte[] dari JS ArrayBuffer
            } catch (JSONException e) {
                callbackContext.error("Invalid ArrayBuffer");
                return true;
            }

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
    private void readerMode(int flags, CallbackContext callbackContext) {
        Log.e(TAG, "readerMode() flags=" + flags);
        readerModeCallback = callbackContext;

        getActivity().runOnUiThread(() -> {
            NfcAdapter nfcAdapter = NfcAdapter.getDefaultAdapter(getActivity());
            try {
                nfcAdapter.disableForegroundDispatch(getActivity());
            } catch (Exception ignored) {}

            nfcAdapter.enableReaderMode(getActivity(), readerCallback, flags, new Bundle());
            Log.e(TAG, "Reader mode enabled");
        });
    }

    private void disableReaderMode(CallbackContext callbackContext) {
        cordova.getActivity().runOnUiThread(() -> {
            NfcAdapter adapter = NfcAdapter.getDefaultAdapter(getActivity());
            adapter.disableReaderMode(getActivity());
            Log.e(TAG, "Reader mode disabled");
            callbackContext.success();
        });
    }

    // ===================== NFC LISTENER =====================
    private final NfcAdapter.ReaderCallback readerCallback = tag -> {
        lastTag = tag;
        Log.e(TAG, "TAG DISCOVERED");
        Log.e(TAG, "Tag techs = " + Arrays.toString(tag.getTechList()));

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
    };

    // ===================== CONNECT =====================
    private void connect(JSONArray args, CallbackContext callbackContext) {
        cordova.getThreadPool().execute(() -> {
            try {
                if (lastTag == null) {
                    Log.e(TAG, "connect() failed: No tag");
                    callbackContext.error("No tag");
                    return;
                }

                isoDep = IsoDep.get(lastTag);
                if (isoDep == null) {
                    Log.e(TAG, "connect() failed: IsoDep not supported");
                    callbackContext.error("IsoDep not supported");
                    return;
                }

                Log.e(TAG, "IsoDep.connect() BEGIN");
                isoDep.connect();
                Log.e(TAG, "IsoDep.connect() OK");

                JSONObject result = new JSONObject();
                result.put("maxTransceiveLength", isoDep.getMaxTransceiveLength());
                callbackContext.success(result);

            } catch (Exception e) {
                Log.e(TAG, "CONNECT FAILED", e);
                callbackContext.error(e.getMessage());
            }
        });
    }

    // ===================== TRANSCEIVE =====================
    private void transceive(byte[] command, CallbackContext callbackContext) {
        cordova.getThreadPool().execute(() -> {
            try {
                if (isoDep == null || !isoDep.isConnected()) {
                    Log.e(TAG, "transceive() failed: IsoDep not connected");
                    callbackContext.error("IsoDep not connected");
                    return;
                }

                Log.e(TAG, "APDU SEND = " + Util.toHexString(command));
                byte[] response = isoDep.transceive(command);
                Log.e(TAG, "APDU RESP = " + Util.toHexString(response));

                callbackContext.success(response);

            } catch (Exception e) {
                Log.e(TAG, "TRANSCEIVE FAILED", e);
                callbackContext.error(e.getMessage());
            }
        });
    }

    // ===================== CLOSE =====================
    private void close(CallbackContext callbackContext) {
        cordova.getThreadPool().execute(() -> {
            try {
                if (isoDep != null) {
                    isoDep.close();
                    isoDep = null;
                }
                Log.e(TAG, "IsoDep closed");
                callbackContext.success();
            } catch (Exception e) {
                Log.e(TAG, "CLOSE FAILED", e);
                callbackContext.error(e.getMessage());
            }
        });
    }

    private Activity getActivity() {
        return cordova.getActivity();
    }
}
