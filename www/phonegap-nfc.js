/*jshint  bitwise: false, camelcase: false, quotmark: false, unused: vars, esversion: 6, browser: true*/
/*global cordova, console, require */

function handleNfcFromIntentFilter() {

    // This was historically done in cordova.addConstructor but broke with PhoneGap-2.2.0.
    // We need to handle NFC from an Intent that launched the application, but *after*
    // the code in the application's deviceready has run.  After upgrading to 2.2.0,
    // addConstructor was finishing *before* deviceReady was complete and the
    // ndef listeners had not been registered.
    // It seems like there should be a better solution.
    if (cordova.platformId === "android" || cordova.platformId === "windows") {
        setTimeout(
            function () {
                cordova.exec(
                    function () {
                        console.log("Initialized the NfcPlugin");
                    },
                    function (reason) {
                        console.log("Failed to initialize the NfcPlugin " + reason);
                    },
                    "NfcPlugin", "init", []
                );
            }, 10
        );
    }
}

document.addEventListener('deviceready', handleNfcFromIntentFilter, false);

// nfc provides javascript wrappers to the native phonegap implementation
var nfc = {

    enabled: function (win, fail) {
        cordova.exec(win, fail, "NfcPlugin", "enabled", [[]]);
    },

    // connect to begin transceive
    connect: function (tech, timeout) {
        return new Promise(function (resolve, reject) {
            cordova.exec(resolve, reject, 'NfcPlugin', 'connect', [tech, timeout]);
        });
    },

    // close transceive connection
    close: function () {
        return new Promise(function (resolve, reject) {
            cordova.exec(resolve, reject, 'NfcPlugin', 'close', []);
        });
    },

    // data - ArrayBuffer or string of hex data for transcieve
    // the results of transceive are returned in the promise success as an ArrayBuffer
    transceive: function (data) {
        return new Promise(function (resolve, reject) {

            var buffer;
            if (typeof data === 'string') {
                buffer = util.hexStringToArrayBuffer(data);
            } else if (data instanceof ArrayBuffer) {
                buffer = data;
            } else if (data instanceof Uint8Array) {
                buffer = data.buffer;
            } else {
                reject("Expecting an ArrayBuffer or String");
            }

            cordova.exec(resolve, reject, 'NfcPlugin', 'transceive', [buffer]);
        });
    },

    // Android NfcAdapter.enableReaderMode flags 
    FLAG_READER_NFC_A: 0x1,
    FLAG_READER_NFC_B: 0x2,
    FLAG_READER_NFC_F: 0x4,
    FLAG_READER_NFC_V: 0x8,
    FLAG_READER_NFC_BARCODE: 0x10,
    FLAG_READER_SKIP_NDEF_CHECK: 0x80,
    FLAG_READER_NO_PLATFORM_SOUNDS: 0x100,

    // Android NfcAdapter.enabledReaderMode
    readerMode: function (flags, readCallback, errorCallback) {
        if (cordova.platformId === "ios") {
            cordova.exec(readCallback, errorCallback, 'NfcPlugin', 'readerMode', []);
        } else {
            cordova.exec(readCallback, errorCallback, 'NfcPlugin', 'readerMode', [flags]);
        }
    },

    disableReaderMode: function (successCallback, errorCallback) {
        cordova.exec(successCallback, errorCallback, 'NfcPlugin', 'disableReaderMode', []);
    }

};

var util = {
    // i must be <= 256
    byteToHex: function (i) {
        if (i < 0) {
            i += 256;
        }
        return i.toString(16).padStart(2, "0");
    },

    bytesToHexString: function (bytes) {
        var dec, hexstring, bytesAsHexString = "";
        for (var i = 0; i < bytes.length; i++) {
            if (bytes[i] >= 0) {
                dec = bytes[i];
            } else {
                dec = 256 + bytes[i];
            }
            hexstring = dec.toString(16);
            // zero padding
            if (hexstring.length === 1) {
                hexstring = "0" + hexstring;
            }
            bytesAsHexString += hexstring;
        }
        return bytesAsHexString;
    },

    /**
     * Convert a hex string to an ArrayBuffer.
     *
     * @param {string} hexString - hex representation of bytes
     * @return {ArrayBuffer} - The bytes in an ArrayBuffer.
     */
    hexStringToArrayBuffer: function (hexString) {

        // remove any delimiters - space, dash, or colon
        hexString = hexString.replace(/[\s-:]/g, '');

        // remove the leading 0x
        hexString = hexString.replace(/^0x/, '');

        // ensure even number of characters
        if (hexString.length % 2 != 0) {
            console.log('WARNING: expecting an even number of characters in the hexString');
        }

        // check for some non-hex characters
        var bad = hexString.match(/[G-Z\s]/i);
        if (bad) {
            console.log('WARNING: found non-hex characters', bad);
        }

        // split the string into pairs of octets
        var pairs = hexString.match(/[\dA-F]{2}/gi);

        // convert the octets to integers
        var ints = pairs.map(function (s) { return parseInt(s, 16) });

        var array = new Uint8Array(ints);
        return array.buffer;
    },

    // Mengubah array byte → string hex dengan spasi. 
    // ex:
    // [6, 6, 23, 7, 89] → "06 06 17 07 59"
    arrayBytesToHexString: function (bytes) {
        return Array.from(bytes).map(b => util.byteToHex(b)).join(" ");
    },
    // Khusus buat convert Card Attribute
    // ex:
    // 17 09 01 → 2017-09-01
    parseCardAttribute: function (bytes) {
        return {
            cardType: bytes[0],
            appVersion: bytes[1],
            issueDate: "20" + util.byteToHex(bytes[2]) + "-" + util.byteToHex(bytes[3]) + "-" + util.byteToHex(bytes[4]),
            expiry: util.byteToHex(bytes[5]) + "/" + util.byteToHex(bytes[6]),
            appletType: bytes[7],
            productId: (bytes[8] << 8) | bytes[9],
            flags: bytes[10]
        };
    },

    // Mengubah Balance (bytes) -> Balance (angka)
    // ex:
    // e80300009000 -> 1000
    parseBalance: function (bytes) {
        if (bytes.length === 4) {
            // NEW APPLET
            var b0 = bytes[0], b1 = bytes[1], b2 = bytes[2], b3 = bytes[3];
            var balance = (b0) | (b1 << 8) | (b2 << 16) | (b3 << 24);
            balance = balance >>> 0;
            return {
                type: "NEW",
                balance: balance,
                raw: util.arrayBytesToHexString(bytes)
            };
        }
        else if (bytes.length >= 10) {
            // OLD APPLET
            var b0 = bytes[0], b1 = bytes[1], b2 = bytes[2], b3 = bytes[3];
            var balance = (b0) | (b1 << 8) | (b2 << 16) | (b3 << 24);
            balance = balance >>> 0;

            var counter = (bytes[4] << 8) | bytes[5];
            var year = 2000 + bytes[6];
            var month = bytes[7];
            var day = bytes[8];
            var hour = bytes[9];
            var min = bytes[10] || 0;

            return {
                type: "OLD",
                balance: balance,
                counter: counter,
                lastTxn: year + "-" + util.byteToHex(month) + "-" + util.byteToHex(day) + " " + util.byteToHex(hour) + ":" + util.byteToHex(min),
                raw: util.arrayBytesToHexString(bytes)
            };
        }
        return null;
    },

    sendApdu: async function (name, hexCmd) {
        var resp = await nfc.transceive(hexCmd);
        var bytes = new Uint8Array(resp);
        var hex = util.bytesToHexString(bytes);

        var sw1 = bytes[bytes.length - 2];
        var sw2 = bytes[bytes.length - 1];
        if (sw1 !== 0x90 || sw2 !== 0x00) {
            throw name + " failed (SW=" + util.byteToHex(sw1) + util.byteToHex(sw2) + ")";
        }

        return bytes;
    }

};

// textHelper and uriHelper aren't exported, add a property
ndef.uriHelper = uriHelper;
ndef.textHelper = textHelper;

// create aliases
nfc.bytesToString = util.bytesToString;
nfc.stringToBytes = util.stringToBytes;
nfc.bytesToHexString = util.bytesToHexString;
nfc.parseCardAttribute = util.parseCardAttribute;
nfc.parseBalance = util.parseBalance;
nfc.sendApdu = util.sendApdu;

/* =========================
 * SECURE APDU HELPERS
 * ========================= */

util.toHexBE = function (num, bytes) {
    var hex = num.toString(16).padStart(bytes * 2, "0");
    return hex;
};

util.encodeDateTime = function (date) {
    function pad(n) { return n.toString().padStart(2, "0"); }
    return (
        pad(date.getDate()) +
        pad(date.getMonth() + 1) +
        pad(date.getFullYear() % 100) +
        pad(date.getHours()) +
        pad(date.getMinutes()) +
        pad(date.getSeconds())
    );
};

// build InputData untuk E5
util.buildUpdateInput = function (p) {
    return (
        util.encodeDateTime(p.date) +           // 6 byte
        "0000000000000000" +                   // CounterCard (8)
        "000000000000" +                       // PIN (6)
        p.session +                            // Session (8)
        p.institutionRef +                     // InstitutionRef (8)
        p.sourceAccount +                      // SourceAccount (10)
        util.toHexBE(p.amount, 4) +             // Amount (4 BE)
        p.merchantData                         // MerchantData (20)
    );
};

/* =========================
 * SECURE COMMANDS
 * ========================= */

nfc.getUpdateData = async function (params) {
    var inputHex = util.buildUpdateInput(params);
    var lc = (inputHex.length / 2).toString(16).padStart(2, "0");

    var apdu = "00E50000" + lc + inputHex;

    var resp = await nfc.sendApdu("Get Update Data (E5)", apdu);
    return resp.slice(0, resp.length - 2);
};

nfc.getReversalData = async function () {
    var resp = await nfc.sendApdu("Get Reversal Data (E7)", "00E70000");
    return resp.slice(0, resp.length - 2);
};

nfc.getCertificate = async function () {
    var resp = await nfc.sendApdu("Get Certificate (E0)", "00E0000000");
    return resp.slice(0, resp.length - 2);
};

nfc.getCardData = async function (tag) {

    var uidFromAndroid = "";

    // ===== ANDROID ONLY =====
    if (cordova.platformId === "android" && tag && tag.id) {
        var tagId = [];
        for (var i = tag.id.length - 1; i >= 0; i--) {
            tagId.push(tag.id[i]);
        }
        uidFromAndroid = nfc.bytesToHexString(tagId);

        await nfc.connect("android.nfc.tech.IsoDep", 5000);
    }

    // 1. SELECT
    var select = await nfc.sendApdu(
        "Select eMoney",
        "00A40400080000000000000001"
    );

    // 2. CARD ATTRIBUTE
    var attr = await nfc.sendApdu(
        "Card Attribute",
        "00F210000B"
    );

    // 3.CardUUID
    try {
        var uidData = await nfc.sendApdu("Card UID (APDU)", "FFCA000000");
        carUUID = "iso:" + nfc.bytesToHexString(uidData);
    } catch (e) {
        carUUID = "nfc:" + uidFromAndroid;
    }

    // 4. CARD INFO
    var info = await nfc.sendApdu(
        "Card Info",
        "00B300003F"
    );

    var hexRaw = util.bytesToHexString(info);
    var cardNumberHex =
        hexRaw.substring(0, 4) + " " +
        hexRaw.substring(4, 8) + " " +
        hexRaw.substring(8, 12) + " " +
        hexRaw.substring(12, 16);

    // 5. LAST BALANCE
    var bal = await nfc.sendApdu(
        "Last Balance",
        "00B500000A"
    );
    var balParsed = util.parseBalance(bal);

    /* =========================
     * SECURE FLOW
     * ========================= */

    // ⚠️ DUMMY INPUT (TEST ONLY)
    var dummyInput =
        "010101010101" +               // Date (6)
        "0000000000000000" +           // Counter (8)
        "000000000000" +               // PIN (6)
        "0011223344556677" +           // Session (8)
        "AABBCCDDEEFF0011" +           // InstitutionRef (8)
        "11223344556677889900" +       // SourceAccount (10)
        "00002710" +                   // Amount (10000)
        "0000000000000000000000000000000000000000"; // Merchant (20)

    var lc = (dummyInput.length / 2).toString(16).padStart(2, "0");

    // 6. GET UPDATE DATA (E5)
    // var updateData = await nfc.sendApdu(
    //     "Get Update Data",
    //     "00E50000" + lc + dummyInput
    // );

    // 7. GET REVERSAL DATA (E7)  ✅ INI YANG KAMU TANYA
    // var reversalData = await nfc.sendApdu(
    //     "Get Reversal Data",
    //     "00E70000"
    // );

    // 8. GET CERTIFICATE (E0)
    var certificate = "";
    try {
        var certificatetemp = await nfc.sendApdu("Certificate", "00E0000000");
        certificate = "iso:" + nfc.bytesToHexString(certificatetemp);
    } catch (e) {
        certificate = "error1:" + e; // langsung tampil "Certificate failed (SW=6400)";
    }

    await nfc.close();

    return {
        selectEmoney: nfc.bytesToHexString(select),
        cardAttribute: nfc.bytesToHexString(attr),
        cardUID: carUUID,
        cardInfo: nfc.bytesToHexString(info),
        lastbalance: nfc.bytesToHexString(bal),
        updateData: nfc.bytesToHexString(attr),
        reversalData: nfc.bytesToHexString(attr),
        certificate: certificate,
        cardNumber: cardNumberHex,
        balance: balParsed.balance
    };
};

// kludge some global variables for plugman js-module support
// eventually these should be replaced and referenced via the module
window.nfc = nfc;
window.ndef = ndef;
window.util = util;
window.fireNfcTagEvent = fireNfcTagEvent;
