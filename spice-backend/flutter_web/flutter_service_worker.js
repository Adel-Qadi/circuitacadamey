'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "69e92efc201b566bccb4f31e50440900",
"assets/AssetManifest.bin.json": "d895d16ef344bb104666814e8a508616",
"assets/AssetManifest.json": "501aa20a6012222c59ebaaa681419186",
"assets/assets/AC_source_0.png": "903e782becb937f5b3e734577e514a8d",
"assets/assets/AC_source_1.png": "71505e8e3c00b8eb3b8e89af1877986a",
"assets/assets/AC_source_10.png": "3648dec21b2d3dfc5d24cd5c5a533ca4",
"assets/assets/AC_source_1000.png": "4c9ca183c47ee67db3e083bb79b2ed89",
"assets/assets/AC_source_2.png": "9639aa8f69ae40daf8cd1b23d77fe955",
"assets/assets/AC_source_20.png": "b163cced4c251be6fa1c00d2e6312b62",
"assets/assets/AC_source_3.png": "ce282284b693b3f1b4f0220e54fbc66b",
"assets/assets/AC_source_30.png": "6d216a60e5f8e2e33dd2442f4dffaad7",
"assets/assets/capacitor_0.png": "d97e572e020ecd11bc8ab66d364200e4",
"assets/assets/capacitor_1.png": "54dbe405500e220ea04bbb626688a73f",
"assets/assets/capacitor_10.png": "3ffd3a0bd0deac2a8ff4e6ece8267d0e",
"assets/assets/capacitor_1000.png": "057aeb903130962289e1bc169679e4b0",
"assets/assets/capacitor_2.png": "da3da6201e2a46139f5812673406cf78",
"assets/assets/capacitor_20.png": "ef160731af1a76fc1252d21f645e6f5a",
"assets/assets/capacitor_3.png": "c03b84a3ef27a7caf120c937fcbb9145",
"assets/assets/capacitor_30.png": "1627c773aa61400229c53fe55100fb39",
"assets/assets/current_source_0.png": "3f52d3c06268e665c8a5ea65cc1a810b",
"assets/assets/current_source_1.png": "2f6da5e86d3ef4b360b4283a1e245471",
"assets/assets/current_source_10.png": "7548e321e3bc5d25eae9eb3be160d441",
"assets/assets/current_source_1000.png": "bad5e4ce39f06c6bac5cf3b33f981148",
"assets/assets/current_source_2.png": "21ae9aa704b08987d1f55c299292c0e3",
"assets/assets/current_source_20.png": "f3da430f9f4216775b09b068fe93c754",
"assets/assets/current_source_3.png": "9e83857f56421b6a845261490acdb3e0",
"assets/assets/current_source_30.png": "8983273b9467fe2b2e5fa413ff3a3c8c",
"assets/assets/diode_0.png": "57d9706d0d237dd7b6a9f5a36cfe6ef4",
"assets/assets/diode_1.png": "9ed6e7429739cbcdc592e82902c97e83",
"assets/assets/diode_10.png": "e164f455f13bc96c94923a8cca634bd8",
"assets/assets/diode_1000.png": "493fd63cfb15651ceadaa6d3af68ec82",
"assets/assets/diode_2.png": "2c1c6e167fb856a1df0a02b24d65fe4a",
"assets/assets/diode_20.png": "45b27a70b853fd44827a89ca6de14c62",
"assets/assets/diode_3.png": "d53bfdb1ece129d0c2396790044ea41a",
"assets/assets/diode_30.png": "a65b9966b81d962b68e084b656e286bb",
"assets/assets/ground_0.png": "552b0d689cb2c3bede1ee642c1616776",
"assets/assets/ground_1.png": "458ed98b321f66a1bcbbfa5d93e37980",
"assets/assets/ground_10.png": "380c021233c01fee512a03e1afeaac47",
"assets/assets/ground_1000.png": "6ae035c2873a5a6c3e68cef9a17ed08b",
"assets/assets/ground_2.png": "b6fe700b17679185aeeefe36a49e5528",
"assets/assets/ground_20.png": "be40a64ab920b90fe06c3d9b2d896dba",
"assets/assets/ground_3.png": "6d6575ac956b2d5d1daa4dedd3ba99b4",
"assets/assets/ground_30.png": "1d8797f0d02ee9c8f1702caa0e472352",
"assets/assets/inductor_0.png": "30bc03e04b1a69185cc2eaf2ed55d840",
"assets/assets/inductor_1.png": "a38a1120c70f9460c5308ede581cbd95",
"assets/assets/inductor_10.png": "1e9e517deb0ebd2342b8065413c2e5e8",
"assets/assets/inductor_1000.png": "c48da953011181244400d9dffcf60ab5",
"assets/assets/inductor_2.png": "fbad614737e6f01f2d8a15818590887e",
"assets/assets/inductor_20.png": "0da1f8503253b82de841fd4843e68a6d",
"assets/assets/inductor_3.png": "3c07c4fbcc5296bb4fd267abbe890f53",
"assets/assets/inductor_30.png": "6114bf6f1b4cf25dede1fcbd068d0875",
"assets/assets/oscilloscope_0.png": "1fd812b834a35e62d3197584185b9c19",
"assets/assets/oscilloscope_1.png": "34e3b396b70cddd57ac879f70572e7b8",
"assets/assets/oscilloscope_10.png": "86615ebdb6acb9a15dcd7bef4102275e",
"assets/assets/oscilloscope_1000.png": "aa54a45f289929ad6339b4b42323d68f",
"assets/assets/oscilloscope_2.png": "1077dbecf32fbeaa5eb447725145db80",
"assets/assets/oscilloscope_20.png": "9863cc95df7dde45563da2cec1defefc",
"assets/assets/oscilloscope_3.png": "8776a1b49c188374724c1631882ba79d",
"assets/assets/oscilloscope_30.png": "ee9ab1b06e61a5b149c4329d48a36037",
"assets/assets/Pulse_source_0.png": "30a0fa672b32fa154b3549d11bbd94e5",
"assets/assets/Pulse_source_1.png": "b8505c59a5f1501c015cb434e79616b8",
"assets/assets/Pulse_source_10.png": "a37eaa8edb0b94bf58be1decbda38ef4",
"assets/assets/Pulse_source_1000.png": "60f2fb231729f13159ca732bf9736371",
"assets/assets/Pulse_source_2.png": "7df3f9fa4117579d386c3a846b33207c",
"assets/assets/Pulse_source_20.png": "2d89090c178c837b2c170a6e4da95109",
"assets/assets/Pulse_source_3.png": "9e0596f2c55dab88eb089bd1bfe3ff99",
"assets/assets/Pulse_source_30.png": "73044d74b7bf2d12463b0950d507b20b",
"assets/assets/resistor_0.png": "20b16e1ed3c634d2524559a49c7f39ab",
"assets/assets/resistor_1.png": "fef80e97a474d7314b77ca7a024cd93b",
"assets/assets/resistor_10.png": "900efb4090d8cd7585ddcde777198d6c",
"assets/assets/resistor_1000.png": "028e242c98c1481d13a0741003aa6fea",
"assets/assets/resistor_2.png": "20b16e1ed3c634d2524559a49c7f39ab",
"assets/assets/resistor_20.png": "3eb67e77255f8bc1b06cecc5689a378e",
"assets/assets/resistor_3.png": "fef80e97a474d7314b77ca7a024cd93b",
"assets/assets/resistor_30.png": "15e2e3b67bb392edc3464f9726305c0d",
"assets/assets/transistor_0.png": "6d0ade41e1af531b987ba18526c00017",
"assets/assets/transistor_1.png": "db4a38f20bb5bb6159c5a5089b879795",
"assets/assets/transistor_10.png": "f599aa265bba9aecfbaee9150ed2e580",
"assets/assets/transistor_1000.png": "9f28a9e1b0da79fb6d8f33b735e2a764",
"assets/assets/transistor_2.png": "7ad8924b2011c15e157bb69bd3acc0a3",
"assets/assets/transistor_20.png": "5464800f21b5edbda730d58591c8bba2",
"assets/assets/transistor_3.png": "b8119ac4214963e8c23a458e2e8dbaf2",
"assets/assets/transistor_30.png": "9dae94ba407a73a9798d8bf3ed549737",
"assets/assets/voltage_source_0.png": "659cceb1239be99b456d043952f667a9",
"assets/assets/voltage_source_1.png": "69e057d1684b901c293d323da461ecfb",
"assets/assets/voltage_source_10.png": "ec87b09688b237d134cdb24a7209277c",
"assets/assets/voltage_source_1000.png": "3dfaec284a7e045b80a5cb0d3da8ef57",
"assets/assets/voltage_source_2.png": "c110fcde5d73396c8a7c8247765adebd",
"assets/assets/voltage_source_20.png": "8f3bcdd4fb672dbf9cc7c69f4feaf534",
"assets/assets/voltage_source_3.png": "255b620f7015cf34e3535b2abf60492d",
"assets/assets/voltage_source_30.png": "1c953e873aa465d282cc6f174dfad84d",
"assets/assets/voltmeter_0.png": "f152eee76298265a40c1ad2721adb0fb",
"assets/assets/voltmeter_1.png": "3f6ed600d0bcba13a85ce3a90a328c72",
"assets/assets/voltmeter_10.png": "80f8098edd9f5a5c4aaa6fd6003b234f",
"assets/assets/voltmeter_1000.png": "193713bb07f0882c958562a0313a2596",
"assets/assets/voltmeter_2.png": "c98c54eb6393091361b83d920c54083b",
"assets/assets/voltmeter_20.png": "1c83021f84e74216f89f3c4b3d3f0425",
"assets/assets/voltmeter_3.png": "cad0c9b06cc2602ca2afbcc2eacca6f9",
"assets/assets/voltmeter_30.png": "d35c356ec3806547444ffe364d829ec2",
"assets/assets/wire_0.png": "7f5b1ed5d07906ddbb7cd1e38571ed47",
"assets/assets/wire_1.png": "da5b914e5dd42526ee5627dc807e39c2",
"assets/assets/wire_10.png": "8c736d9b6974f560246e898077c6d289",
"assets/assets/wire_1000.png": "aa5dc80cdd8ba0b204a4fd6fb88d79e8",
"assets/assets/wire_11.png": "43e6bcbcf9191d9e4792d6a882cc4f87",
"assets/assets/wire_110.png": "6bacff552e3f014d0c2e68a7eb496b6b",
"assets/assets/wire_2.png": "ab723aaf75de42bc61e3250ab2e7da13",
"assets/assets/wire_20.png": "8a9591eaeec651030e9b0db1fb1367ce",
"assets/assets/wire_3.png": "adce133c1ea68e7e000ab02f332ad754",
"assets/assets/wire_30.png": "697cd111f7d6ad0a3b6ff0fb2bc4a72a",
"assets/assets/wire_4.png": "c3383ef798a4513ae8fa81aab76433d1",
"assets/assets/wire_40.png": "bf519159f06512ca4e57051e232602e2",
"assets/assets/wire_5.png": "f5656d903c9fd4de2584074adf283652",
"assets/assets/wire_50.png": "1de1652c59a6a29c1d6f6cf867f95a4b",
"assets/assets/wire_6.png": "552c481310755c572ec916feb97b84fd",
"assets/assets/wire_60.png": "067bb86eb252bb6d36420a2d05973b05",
"assets/assets/wire_7.png": "d0f52b671f7225070f581d3c8f4dd614",
"assets/assets/wire_70.png": "d92622ff0a126769380174df90c51bdb",
"assets/assets/wire_8.png": "4697df45121b9b52bbefc91e15ce7ea5",
"assets/assets/wire_80.png": "709bbc30ce68dc3912daf1b30985d850",
"assets/assets/wire_9.png": "20a5c0a4c79c3fcabbe4defbe2611d9c",
"assets/assets/wire_90.png": "b47fce9549f963eb9db0f56f8bdb40a2",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/fonts/MaterialIcons-Regular.otf": "1e024c3996b02463ed7036b7bd39a264",
"assets/NOTICES": "83742fe9594b3c27cf0d9072051724b6",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"canvaskit/canvaskit.js": "6cfe36b4647fbfa15683e09e7dd366bc",
"canvaskit/canvaskit.js.symbols": "68eb703b9a609baef8ee0e413b442f33",
"canvaskit/canvaskit.wasm": "efeeba7dcc952dae57870d4df3111fad",
"canvaskit/chromium/canvaskit.js": "ba4a8ae1a65ff3ad81c6818fd47e348b",
"canvaskit/chromium/canvaskit.js.symbols": "5a23598a2a8efd18ec3b60de5d28af8f",
"canvaskit/chromium/canvaskit.wasm": "64a386c87532ae52ae041d18a32a3635",
"canvaskit/skwasm.js": "f2ad9363618c5f62e813740099a80e63",
"canvaskit/skwasm.js.symbols": "80806576fa1056b43dd6d0b445b4b6f7",
"canvaskit/skwasm.wasm": "f0dfd99007f989368db17c9abeed5a49",
"canvaskit/skwasm_st.js": "d1326ceef381ad382ab492ba5d96f04d",
"canvaskit/skwasm_st.js.symbols": "c7e7aac7cd8b612defd62b43e3050bdd",
"canvaskit/skwasm_st.wasm": "56c3973560dfcbf28ce47cebe40f3206",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"flutter.js": "76f08d47ff9f5715220992f993002504",
"flutter_bootstrap.js": "641a4b46d32e895bd359b15e6992a94a",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"index.html": "b2d9c002431b6f901cd675bda65ddf70",
"/": "b2d9c002431b6f901cd675bda65ddf70",
"main.dart.js": "d15eb1166a5513c57e37a1e2ead521b9",
"manifest.json": "bf24c84c3bf99672a631c4f84464e793",
"version.json": "15235b5108d6a877ef74fe3317a96bf7"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
