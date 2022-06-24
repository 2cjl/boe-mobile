package com.example.boe_mobile;

import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

import android.Manifest;
import android.annotation.SuppressLint;
import android.content.pm.PackageManager;
import android.net.wifi.WifiManager;
import android.os.Build;
import android.provider.Settings;
import android.text.format.Formatter;

import java.net.NetworkInterface;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "tclx.xyz/info";

    @SuppressLint("HardwareIds")
    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler(
                        (call, result) -> {
                            if (call.method.equals("getDeivceInfo")) {
                                Map<String, Object> map = new HashMap<>();
                                map.put("brand", Build.BRAND);
                                map.put("deviceID", Settings.Secure.getString(
                                        getContext().getContentResolver(),
                                        Settings.Secure.ANDROID_ID
                                ));
                                map.put("model", Build.MODEL);
                                map.put("id", Build.ID);
                                map.put("sdk", Build.VERSION.SDK_INT);
                                map.put("manufacture", Build.MANUFACTURER);
                                map.put("user", Build.USER);
                                map.put("type", Build.TYPE);
                                map.put("incremental", Build.VERSION.INCREMENTAL);
                                map.put("board", Build.BOARD);
                                map.put("host", Build.HOST);
                                map.put("fingerPrint", Build.FINGERPRINT);
                                map.put("versionCode", Build.VERSION.RELEASE);

                                // ip
                                WifiManager wifiManager = (WifiManager) getApplicationContext().getSystemService(WIFI_SERVICE);
                                String ip = Formatter.formatIpAddress(wifiManager.getConnectionInfo().getIpAddress());
                                map.put("ip", ip);
                                map.put("mac", getMacAddress());
                                result.success(map);
//                                result.error("UNAVAILABLE", "Battery level not available.", null);
                            } else {
                                result.notImplemented();
                            }
                        }
                );
    }

    private String getMacAddress(){
        try {
            List<NetworkInterface> all = Collections.list(NetworkInterface.getNetworkInterfaces());
            for (NetworkInterface nif : all) {
                if (!nif.getName().equalsIgnoreCase("wlan0")) continue;
                byte[] macBytes = nif.getHardwareAddress();
                if (macBytes == null) {
                    return "";
                }
                StringBuilder res1 = new StringBuilder();
                for (byte b : macBytes) {
                    res1.append(String.format("%02X:",b));
                }
                if (res1.length() > 0) {
                    res1.deleteCharAt(res1.length() - 1);
                }
                return res1.toString();
            }
        } catch (Exception ex) {
        }
        return "02:00:00:00:00:00";
    }
}
