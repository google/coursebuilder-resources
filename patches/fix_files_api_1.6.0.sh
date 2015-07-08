#!/bin/sh

# Copyright 2015 Google Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS-IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

cat <<EOF

This script applies (or un-applies) a patch set that removes Course Builder's
dependencies on the deprecated Blobstore Files API.  See
https://cloud.google.com/appengine/docs/deprecations/files_api for more detail
on the timeline of the service turndown.

To use this script, change to the directory containing your Course Builder
code.  This is probably named "coursebuilder", and will contain files like
"app.yaml", "main.py" and so on.  You want to be in the same directory as
those files.

To apply the patches, simply run this script by entering the command:
sh fix_files_api.sh

If you wish to un-apply the patch set, simply run this script again.  The patch
program will notice that the patch has already been applied, and you will see
messages similar to the following line for each file being (un)patched:
   Reversed (or previously applied) patch detected!  Assuming -R.


EOF

if [[ ! -f 'app.yaml' ]] ; then
  echo '------------------------- ERROR -----------------------------'
  echo "You do not seem to be in the right directory to apply this patch."
  echo "Please change directory to within the coursebuilder directory.  "
  echo "That's the directory that contains files such as app.yaml, main.py"
  echo "and so on."
  echo ""
  exit 1
fi

grep "GCB_PRODUCT_VERSION: '1.6.0'" app.yaml > /dev/null 2>&1

if [[ $? -eq 0 ]] ; then
  echo "Looks like a Course Builder 1.6.0 release; proceeding."; 
else 
  echo '------------------------- ERROR -----------------------------'
  echo "This patch will only apply cleanly against Course Builder "
  echo "version 1.6.0.  You may try manually applying the patch by "
  echo "modifying this script to remove this check, but be advised "
  echo "that you are proceeding at your own risk if you do so."
  echo ""
  exit 1
fi

export TMPFILE=/tmp/files_api.patch

# Fail on any error here and below.
set -e

cat > $TMPFILE <<EOF
diff -rupN coursebuilder_1.6.0/appengine_config.py coursebuilder/appengine_config.py
--- coursebuilder_1.6.0/appengine_config.py	2014-02-21 14:41:22.000000000 -0800
+++ coursebuilder/appengine_config.py	2015-06-26 07:38:25.460145784 -0700
@@ -59,23 +59,36 @@ class _Library(object):
         return path
 
 
+# Google-produced library zip files.
+GOOGLE_LIBS = [
+    _Library(
+        'google-api-python-client-1.1.zip',
+        relative_path='google-api-python-client-1.1'),
+    _Library('GoogleAppEngineCloudStorageClient-1.9.15.0.zip',
+             relative_path='GoogleAppEngineCloudStorageClient-1.9.15.0'),
+    _Library('GoogleAppEnginePipeline-1.9.17.0.zip',
+             relative_path='GoogleAppEnginePipeline-1.9.17.0'),
+]
+
 # Third-party library zip files.
 THIRD_PARTY_LIBS = [
+    _Library('appengine-mapreduce-0.8.2.zip',
+             relative_path='appengine-mapreduce-0.8.2/python/src'),
     _Library('babel-0.9.6.zip'),
     _Library('html5lib-0.95.zip'),
     _Library('httplib2-0.8.zip', relative_path='httplib2-0.8/python2'),
     _Library('gaepytz-2011h.zip'),
-    _Library(
-        'google-api-python-client-1.1.zip',
-        relative_path='google-api-python-client-1.1'),
-    _Library('mapreduce-r645.zip'),
+    _Library('Graphy-1.0.0.zip', relative_path='Graphy-1.0.0'),
     # .zip repackaged from .tar.gz download.
     _Library('mrs-mapreduce-0.9.zip', relative_path='mrs-mapreduce-0.9'),
     # .zip repackaged from .tar.gz download.
     _Library('python-gflags-2.0.zip', relative_path='python-gflags-2.0'),
     _Library('pyparsing-1.5.7.zip'),
+    _Library('simplejson-3.7.1.zip', relative_path='simplejson-3.7.1'),
 ]
 
+ALL_LIBS = GOOGLE_LIBS + THIRD_PARTY_LIBS
+
 
 def gcb_force_default_encoding(encoding):
     """Force default encoding to a specific value."""
@@ -89,7 +102,7 @@ def gcb_force_default_encoding(encoding)
 
 def gcb_init_third_party():
     """Add all third party libraries to system path."""
-    for lib in THIRD_PARTY_LIBS:
+    for lib in ALL_LIBS:
         if not os.path.exists(lib.file_path):
             raise Exception('Library does not exist: %s' % lib.file_path)
         sys.path.insert(0, lib.full_path)
Binary files coursebuilder_1.6.0/lib/appengine-mapreduce-0.8.2.zip and coursebuilder/lib/appengine-mapreduce-0.8.2.zip differ
Binary files coursebuilder_1.6.0/lib/GoogleAppEngineCloudStorageClient-1.9.15.0.zip and coursebuilder/lib/GoogleAppEngineCloudStorageClient-1.9.15.0.zip differ
Binary files coursebuilder_1.6.0/lib/GoogleAppEnginePipeline-1.9.17.0.zip and coursebuilder/lib/GoogleAppEnginePipeline-1.9.17.0.zip differ
Binary files coursebuilder_1.6.0/lib/Graphy-1.0.0.zip and coursebuilder/lib/Graphy-1.0.0.zip differ
Binary files coursebuilder_1.6.0/lib/mapreduce-r645.zip and coursebuilder/lib/mapreduce-r645.zip differ
Binary files coursebuilder_1.6.0/lib/simplejson-3.7.1.zip and coursebuilder/lib/simplejson-3.7.1.zip differ
diff -rupN coursebuilder_1.6.0/models/jobs.py coursebuilder/models/jobs.py
--- coursebuilder_1.6.0/models/jobs.py	2014-02-21 14:41:22.000000000 -0800
+++ coursebuilder/models/jobs.py	2015-06-29 06:59:17.154655922 -0700
@@ -27,11 +27,14 @@ import entities
 from mapreduce import base_handler
 from mapreduce import input_readers
 from mapreduce import mapreduce_pipeline
+from mapreduce import output_writers
+from pipeline import pipeline
 import transforms
 
 from common.utils import Namespace
 
 from google.appengine import runtime
+from google.appengine.api import app_identity
 from google.appengine.ext import db
 from google.appengine.ext import deferred
 
@@ -127,12 +130,13 @@ class StoreMapReduceResults(base_handler
         # TODO(mgainer): Notice errors earlier in pipeline, and mark job
         # as failed in that case as well.
         try:
-            iterator = input_readers.RecordsReader(output, 0)
-            for item in iterator:
-                # Map/reduce puts reducer output into blobstore files as a
-                # string obtained via "str(result)".  Use AST as a safe
-                # alternative to eval() to get the Python object back.
-                results.append(ast.literal_eval(item))
+            iterator = input_readers.GoogleCloudStorageInputReader(output, 0)
+            for file_reader in iterator:
+                for item in file_reader:
+                    # Map/reduce puts reducer output into blobstore files as a
+                    # string obtained via "str(result)".  Use AST as a safe
+                    # alternative to eval() to get the Python object back.
+                    results.append(ast.literal_eval(item))
             time_completed = time.time()
             with Namespace(namespace):
                 db.run_in_transaction(DurableJobEntity._complete_job, job_name,
@@ -155,6 +159,20 @@ class StoreMapReduceResults(base_handler
                                       long(time_completed - time_started))
 
 
+class GoogleCloudStorageConsistentOutputReprWriter(
+    output_writers.GoogleCloudStorageConsistentOutputWriter):
+
+    def write(self, data):
+        if isinstance(data, basestring):
+            # Convert from unicode, as returned from transforms.dumps()
+            data = str(data)
+            if not data.endswith('\n'):
+                data += '\n'
+        else:
+            data = repr(data) + '\n'
+        super(GoogleCloudStorageConsistentOutputReprWriter, self).write(data)
+
+
 class MapReduceJob(DurableJobBase):
 
     # The 'output' field in the DurableJobEntity representing a MapReduceJob
@@ -267,6 +285,25 @@ class MapReduceJob(DurableJobBase):
         if self.is_active():
             return
         super(MapReduceJob, self).non_transactional_submit()
+
+        mapper_params = {
+            'entity_kind': self.entity_type_name(),
+            'namespace': self._namespace,
+        }
+
+        # Config parameters for reducer, output writer stages.  Copy from
+        # mapper_params so that the implemented reducer function also gets
+        # to see any parameters built by build_additional_mapper_params().
+        reducer_params = {}
+        reducer_params.update(mapper_params)
+        bucket_name = app_identity.get_default_gcs_bucket_name()
+        reducer_params.update({
+            'output_writer': {
+                output_writers.GoogleCloudStorageOutputWriter.BUCKET_NAME_PARAM:
+                    bucket_name,
+            }
+        })
+
         kwargs = {
             'job_name': self._job_name,
             'mapper_spec': '%s.%s.map' % (
@@ -276,11 +313,9 @@ class MapReduceJob(DurableJobBase):
             'input_reader_spec':
                 'mapreduce.input_readers.DatastoreInputReader',
             'output_writer_spec':
-                'mapreduce.output_writers.BlobstoreRecordsOutputWriter',
-            'mapper_params': {
-                'entity_kind': self.entity_type_name(),
-                'namespace': self._namespace,
-            },
+                'models.jobs.GoogleCloudStorageConsistentOutputReprWriter',
+            'mapper_params': mapper_params,
+            'reducer_params': reducer_params,
         }
         mr_pipeline = MapReduceJobPipeline(self._job_name, kwargs,
                                            self._namespace)
diff -rupN coursebuilder_1.6.0/modules/mapreduce/mapreduce_module.py coursebuilder/modules/mapreduce/mapreduce_module.py
--- coursebuilder_1.6.0/modules/mapreduce/mapreduce_module.py	2014-02-21 14:41:22.000000000 -0800
+++ coursebuilder/modules/mapreduce/mapreduce_module.py	2015-06-29 06:51:37.846125697 -0700
@@ -16,8 +16,14 @@
 
 __author__ = 'Mike Gainer (mgainer@google.com)'
 
+import logging
+
+import cloudstorage
+
 from mapreduce import main as mapreduce_main
 from mapreduce import parameters as mapreduce_parameters
+from pipeline import models as pipeline_models
+from pipeline import pipeline
 
 from common import safe_dom
 from common.utils import Namespace
EOF

patch --batch -p1 < $TMPFILE
rm -f $TMPFILE
cat <<EOF

Patch complete.

This change set requires some additional .zip files that will be automatically
downloaded and installed for you if you use .../scripts/deploy.sh to upload
this change.  (This will also automatically happen if you use any of the other
convenience scripts -- start_in_shell.sh, run_all_tests.sh, etc.)

Once the required libraries are present, you may upload your application to
App Engine using your normal deployment process.  As with any deployment, You
may wish to consider using a new version number to facilitate a rollback in
the event that you encounter any problems.

EOF
