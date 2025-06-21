'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "db82487dafe5ebcb55689b686b1b091a",
"assets/AssetManifest.bin.json": "171ebee09004cabff91df57c90418739",
"assets/AssetManifest.json": "fa247fb755953ea3fd0b1b56751ba1c1",
"assets/assets/capacitor_0.png": "d97e572e020ecd11bc8ab66d364200e4",
"assets/assets/capacitor_1.png": "54dbe405500e220ea04bbb626688a73f",
"assets/assets/capacitor_10.png": "3ffd3a0bd0deac2a8ff4e6ece8267d0e",
"assets/assets/capacitor_1000.png": "057aeb903130962289e1bc169679e4b0",
"assets/assets/capacitor_2.png": "da3da6201e2a46139f5812673406cf78",
"assets/assets/capacitor_20.png": "ef160731af1a76fc1252d21f645e6f5a",
"assets/assets/capacitor_3.png": "c03b84a3ef27a7caf120c937fcbb9145",
"assets/assets/capacitor_30.png": "1627c773aa61400229c53fe55100fb39",
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
"assets/assets/resistor_0.png": "20b16e1ed3c634d2524559a49c7f39ab",
"assets/assets/resistor_1.png": "fef80e97a474d7314b77ca7a024cd93b",
"assets/assets/resistor_10.png": "900efb4090d8cd7585ddcde777198d6c",
"assets/assets/resistor_1000.png": "028e242c98c1481d13a0741003aa6fea",
"assets/assets/resistor_2.png": "20b16e1ed3c634d2524559a49c7f39ab",
"assets/assets/resistor_20.png": "3eb67e77255f8bc1b06cecc5689a378e",
"assets/assets/resistor_3.png": "fef80e97a474d7314b77ca7a024cd93b",
"assets/assets/resistor_30.png": "15e2e3b67bb392edc3464f9726305c0d",
"assets/assets/voltage_source_0.png": "659cceb1239be99b456d043952f667a9",
"assets/assets/voltage_source_1.png": "69e057d1684b901c293d323da461ecfb",
"assets/assets/voltage_source_10.png": "ec87b09688b237d134cdb24a7209277c",
"assets/assets/voltage_source_1000.png": "3dfaec284a7e045b80a5cb0d3da8ef57",
"assets/assets/voltage_source_2.png": "c110fcde5d73396c8a7c8247765adebd",
"assets/assets/voltage_source_20.png": "8f3bcdd4fb672dbf9cc7c69f4feaf534",
"assets/assets/voltage_source_3.png": "255b620f7015cf34e3535b2abf60492d",
"assets/assets/voltage_source_30.png": "1c953e873aa465d282cc6f174dfad84d",
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
"assets/fonts/MaterialIcons-Regular.otf": "23bad345c4405e7e08eecf41442d3d2c",
"assets/NOTICES": "801b9071543607c1d4f3cca9116d1cee",
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
"flutter_bootstrap.js": "b3de4b7bfbff075d46cb73da0b89efe9",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"index.html": "b2d9c002431b6f901cd675bda65ddf70",
"/": "b2d9c002431b6f901cd675bda65ddf70",
"main.dart.js": "61b8457861394ca677994bde8380c6d4",
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
