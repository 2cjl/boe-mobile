package com.example.boe_mobile;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.app.ActivityCompat;

import io.flutter.Log;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

import android.Manifest;
import android.annotation.SuppressLint;
import android.app.Activity;
import android.app.ActivityManager;
import android.content.Context;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.graphics.Point;
import android.net.wifi.WifiManager;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.os.StatFs;
import android.os.SystemClock;
import android.provider.Settings;
import android.text.format.Formatter;
import android.util.Base64;
import android.view.WindowManager;

import java.io.ByteArrayOutputStream;
import java.net.NetworkInterface;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "tclx.xyz/info";
    private String[] units = {"B", "KB", "MB", "GB", "TB"};
    private static final int REQUEST_EXTERNAL_STORAGe = 1;
    private static String[] permissionstorage = {
            Manifest.permission.ACCESS_WIFI_STATE,
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION,
    };

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        verifystoragepermissions(this);
    }

    @SuppressLint("HardwareIds")
    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler(
                        (call, result) -> {
                            if (call.method.equals("getDeivceInfo")) {
                                Map<String, Object> map = new HashMap<>();
                                map.put("hardwareId", Settings.Secure.getString(
                                        getContext().getContentResolver(),
                                        Settings.Secure.ANDROID_ID
                                ));
                                map.put("model", Build.MODEL);

                                // 屏幕
                                WindowManager windowManager = getWindow().getWindowManager();
                                Point point = new Point();
                                windowManager.getDefaultDisplay().getRealSize(point);
                                map.put("resolution", point.x + "x" + point.y);

                                // size
                                StatFs sf = new StatFs(Environment.getExternalStorageDirectory().getPath());
                                long totalSize = sf.getTotalBytes();
                                long availableSize = sf.getAvailableBytes();
                                map.put("storage", getUnit(availableSize) + " 可用（共 " + getUnit(totalSize) + "）");

                                // ram
                                ActivityManager manager = (ActivityManager) getSystemService(Context.ACTIVITY_SERVICE);
                                ActivityManager.MemoryInfo info = new ActivityManager.MemoryInfo();
                                manager.getMemoryInfo(info);
                                map.put("memory", getUnit(info.totalMem));

                                // app version
                                try {
                                    PackageManager pm = getPackageManager();
                                    PackageInfo pi = pm.getPackageInfo(getPackageName(), 0);
                                    String versionName = pi.versionName;
                                    map.put("appVersion", versionName);
                                } catch (Exception e) {
                                    Log.e("VersionInfo", "Exception", e);
                                }

                                // running time
                                map.put("runningTime", SystemClock.elapsedRealtime());

                                // ip
                                WifiManager wifiManager = (WifiManager) getApplicationContext().getSystemService(WIFI_SERVICE);
                                String ip = Formatter.formatIpAddress(wifiManager.getConnectionInfo().getIpAddress());
                                map.put("ip", ip);
                                result.success(map);
//                                result.error("UNAVAILABLE", "Battery level not available.", null);
                            } else if (call.method.equals("getMacAddress")) {
                                result.success(getMacAddress());
                            } else if (call.method.equals("getRunningTime")) {
                                result.success(SystemClock.elapsedRealtime());
                            } else {
                                result.notImplemented();
                            }
                        }
                );
    }

    private String getMacAddress() {
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
                    res1.append(String.format("%02X:", b));
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

    private String getUnit(float size) {
        int index = 0;
        while (size > 1024 && index < 4) {
            size = size / 1024;
            index++;
        }
        return String.format(Locale.getDefault(), " %.2f %s", size, units[index]);
    }

    public static void verifystoragepermissions(Activity activity) {

        int permissions = ActivityCompat.checkSelfPermission(activity, Manifest.permission.WRITE_EXTERNAL_STORAGE);

        // If storage permission is not given then request for External Storage Permission
        if (permissions != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(activity, permissionstorage, REQUEST_EXTERNAL_STORAGe);
        }
    }

    public byte[] capture(Activity activity) {
        activity.getWindow().getDecorView().setDrawingCacheEnabled(true);
        Bitmap bitmap = activity.getWindow().getDecorView().getDrawingCache();
        ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
        bitmap.compress(Bitmap.CompressFormat.JPEG, 100, outputStream);
        Log.i("out", Arrays.toString(outputStream.toByteArray()));
        String encoded = Base64.encodeToString(outputStream.toByteArray(), Base64.DEFAULT);
//        Log.i("base64", encoded);
        return outputStream.toByteArray();
    }
}
