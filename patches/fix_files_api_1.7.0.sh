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

grep "GCB_PRODUCT_VERSION: '1.7.0'" app.yaml > /dev/null 2>&1

if [[ $? -eq 0 ]] ; then
  echo "Looks like a Course Builder 1.7.0 release; proceeding."; 
else 
  echo '------------------------- ERROR -----------------------------'
  echo "This patch will only apply cleanly against Course Builder "
  echo "version 1.7.0.  You may try manually applying the patch by "
  echo "modifying this script to remove this check, but be advised "
  echo "that you are proceeding at your own risk if you do so."
  echo ""
  exit 1
fi

export TMPFILE=/tmp/files_api.patch

# Fail on any error here and below.
set -e

cat > $TMPFILE <<EOF
diff -rupN coursebuilder_1.7.0/appengine_config.py coursebuilder/appengine_config.py
--- coursebuilder_1.7.0/appengine_config.py	2014-10-10 11:33:52.000000000 -0700
+++ coursebuilder/appengine_config.py	2015-06-26 06:54:38.372834450 -0700
@@ -63,24 +63,35 @@ class _Library(object):
             path = os.path.join(path, self._relative_path)
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
     _Library('markdown-2.5.zip', relative_path='Markdown-2.5'),
     _Library('mrs-mapreduce-0.9.zip', relative_path='mrs-mapreduce-0.9'),
     _Library('python-gflags-2.0.zip', relative_path='python-gflags-2.0'),
     _Library('oauth-1.0.1.zip', relative_path='oauth'),
     _Library('pyparsing-1.5.7.zip'),
+    _Library('simplejson-3.7.1.zip', relative_path='simplejson-3.7.1'),
 ]
 
+ALL_LIBS = GOOGLE_LIBS + THIRD_PARTY_LIBS
 
 def gcb_force_default_encoding(encoding):
     """Force default encoding to a specific value."""
@@ -105,7 +116,7 @@ def _third_party_libs_from_env():
 
 def gcb_init_third_party():
     """Add all third party libraries to system path."""
-    for lib in THIRD_PARTY_LIBS + _third_party_libs_from_env():
+    for lib in ALL_LIBS + _third_party_libs_from_env():
         if not os.path.exists(lib.file_path):
             raise Exception('Library does not exist: %s' % lib.file_path)
         sys.path.insert(0, lib.full_path)
diff -rupN coursebuilder_1.7.0/common/utils.py coursebuilder/common/utils.py
--- coursebuilder_1.7.0/common/utils.py	2014-10-10 11:33:52.000000000 -0700
+++ coursebuilder/common/utils.py	2015-06-26 06:48:38.733500261 -0700
@@ -160,8 +160,7 @@ class ZipAwareOpen(object):
             third_party_module.some_func_that_calls_open()
     """
 
-    THIRD_PARTY_LIB_PATHS = {
-        l.file_path: l.full_path for l in appengine_config.THIRD_PARTY_LIBS}
+    LIB_PATHS = {l.file_path: l.full_path for l in appengine_config.ALL_LIBS}
 
     def zip_aware_open(self, name, *args, **kwargs):
         """Override open() iff opening a file in a library .zip for reading."""
@@ -173,7 +172,7 @@ class ZipAwareOpen(object):
 
             # Only consider .zip files known in the third-party libraries
             # registered in appengine_config.py
-            for path in ZipAwareOpen.THIRD_PARTY_LIB_PATHS:
+            for path in ZipAwareOpen.LIB_PATHS:
 
                 # Don't use zip-open if the file we are looking for _is_
                 # the sought .zip file.  (We are recursed into from the
@@ -184,7 +183,7 @@ class ZipAwareOpen(object):
                     # Possibly extend simple path to .zip file with relative
                     # path inside .zip file to meaningful contents.
                     name = name.replace(
-                        path, ZipAwareOpen.THIRD_PARTY_LIB_PATHS[path])
+                        path, ZipAwareOpen.LIB_PATHS[path])
 
                     # Strip off on-disk path to .zip file.  This leaves
                     # us with the absolute path within the .zip file.
Binary files coursebuilder_1.7.0/lib/appengine-mapreduce-0.8.2.zip and coursebuilder/lib/appengine-mapreduce-0.8.2.zip differ
Binary files coursebuilder_1.7.0/lib/GoogleAppEngineCloudStorageClient-1.9.15.0.zip and coursebuilder/lib/GoogleAppEngineCloudStorageClient-1.9.15.0.zip differ
Binary files coursebuilder_1.7.0/lib/GoogleAppEnginePipeline-1.9.17.0.zip and coursebuilder/lib/GoogleAppEnginePipeline-1.9.17.0.zip differ
Binary files coursebuilder_1.7.0/lib/Graphy-1.0.0.zip and coursebuilder/lib/Graphy-1.0.0.zip differ
Binary files coursebuilder_1.7.0/lib/mapreduce-r645.zip and coursebuilder/lib/mapreduce-r645.zip differ
Binary files coursebuilder_1.7.0/lib/simplejson-3.7.1.zip and coursebuilder/lib/simplejson-3.7.1.zip differ
diff -rupN coursebuilder_1.7.0/models/jobs.py coursebuilder/models/jobs.py
--- coursebuilder_1.7.0/models/jobs.py	2014-10-10 11:33:52.000000000 -0700
+++ coursebuilder/models/jobs.py	2015-06-26 06:59:17.519307891 -0700
@@ -27,11 +27,13 @@ import entities
 from mapreduce import base_handler
 from mapreduce import input_readers
 from mapreduce import mapreduce_pipeline
-from mapreduce.lib.pipeline import pipeline
+from mapreduce import output_writers
+from pipeline import pipeline
 import transforms
 from common.utils import Namespace
 
 from google.appengine import runtime
+from google.appengine.api import app_identity
 from google.appengine.api import users
 from google.appengine.ext import db
 from google.appengine.ext import deferred
@@ -186,12 +188,13 @@ class StoreMapReduceResults(base_handler
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
                 db.run_in_transaction(
@@ -213,6 +216,20 @@ class StoreMapReduceResults(base_handler
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
@@ -394,6 +411,19 @@ class MapReduceJob(DurableJobBase):
             'namespace': self._namespace,
             })
 
+        # Config parameters for reducer, output writer stages.  Copy from
+        # mapper_params so that the implemented reducer function also gets
+        # to see any parameters built by build_additional_mapper_params().
+        reducer_params = {}
+        reducer_params.update(self.mapper_params)
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
@@ -403,8 +433,9 @@ class MapReduceJob(DurableJobBase):
             'input_reader_spec':
                 'mapreduce.input_readers.DatastoreInputReader',
             'output_writer_spec':
-                'mapreduce.output_writers.BlobstoreRecordsOutputWriter',
+                'models.jobs.GoogleCloudStorageConsistentOutputReprWriter',
             'mapper_params': self.mapper_params,
+            'reducer_params': reducer_params,
         }
         mr_pipeline = MapReduceJobPipeline(self._job_name, sequence_num,
                                            kwargs, self._namespace)
diff -rupN coursebuilder_1.7.0/modules/mapreduce/mapreduce_module.py coursebuilder/modules/mapreduce/mapreduce_module.py
--- coursebuilder_1.7.0/modules/mapreduce/mapreduce_module.py	2014-10-10 11:33:52.000000000 -0700
+++ coursebuilder/modules/mapreduce/mapreduce_module.py	2015-06-26 06:48:38.733500261 -0700
@@ -17,13 +17,14 @@
 __author__ = 'Mike Gainer (mgainer@google.com)'
 
 import datetime
-import re
+import logging
 import urllib
 
+import cloudstorage
 from mapreduce import main as mapreduce_main
 from mapreduce import parameters as mapreduce_parameters
-from mapreduce.lib.pipeline import models as pipeline_models
-from mapreduce.lib.pipeline import pipeline
+from pipeline import models as pipeline_models
+from pipeline import pipeline
 
 from common import safe_dom
 from common.utils import Namespace
@@ -32,11 +33,8 @@ from controllers import utils
 from models import custom_modules
 from models import data_sources
 from models import jobs
-from models import roles
-from models import transforms
 from models.config import ConfigProperty
 
-from google.appengine.api import files
 from google.appengine.api import users
 from google.appengine.ext import db
 
@@ -156,7 +154,7 @@ class CronMapreduceCleanupHandler(utils.
 
         # Belt and suspenders.  The app.yaml settings should ensure that
         # only admins can use this URL, but check anyhow.
-        if not roles.Roles.is_direct_super_admin():
+        if 'X-AppEngine-Cron' not in self.request.headers:
             self.error(400)
             return
 
@@ -164,7 +162,7 @@ class CronMapreduceCleanupHandler(utils.
             datetime.timedelta(days=MAX_MAPREDUCE_METADATA_RETENTION_DAYS))
 
     @classmethod
-    def _collect_blobstore_paths(cls, root_key):
+    def _collect_cloudstore_paths(cls, root_key):
         paths = set()
         # pylint: disable-msg=protected-access
         for model, field_name in ((pipeline_models._SlotRecord, 'value'),
@@ -183,19 +181,31 @@ class CronMapreduceCleanupHandler(utils.
                     # vary widely, but all are provided via this interface as
                     # some combination of Python scalar, list, tuple, and
                     # dict.  Rather than depend on specifics of the map/reduce
-                    # internals, crush the object to a string and parse that.
+                    # internals, manually rummage around.  Experiment shows
+                    # this to be sufficient.
                     try:
                         data_object = getattr(record, field_name)
                     except TypeError:
                         data_object = None
-                    if data_object:
-                        text = transforms.dumps(data_object)
-                        for path in re.findall(r'"(/blobstore/[^"]+)"', text):
-                            paths.add(path)
+                    if (data_object and
+                        isinstance(data_object, list) and
+                        all(isinstance(x, basestring) for x in data_object) and
+                        all(x[0] == '/' for x in data_object)
+                    ):
+                        paths.update(data_object)
                 prev_cursor = query.cursor()
         return paths
 
     @classmethod
+    def _clean_cloudstore_paths_for_key(cls, root_key, min_start_time_millis):
+        for path in cls._collect_cloudstore_paths(root_key):
+            try:
+                cloudstorage.delete(path)
+                logging.info('Deleted cloud storage file %s', path)
+            except cloudstorage.NotFoundError:
+                logging.info('Cloud storage file %s already deleted', path)
+
+    @classmethod
     def _clean_mapreduce(cls, max_age):
         """Separated as internal function to permit tests to pass max_age."""
         num_cleaned = 0
@@ -250,8 +260,8 @@ class CronMapreduceCleanupHandler(utils.
                             root_key = db.Key.from_path(
                                 pipeline_models._PipelineRecord.kind(),
                                 pipeline_id)
-                            for path in cls._collect_blobstore_paths(root_key):
-                                files.delete(path)
+                            cls._clean_cloudstore_paths_for_key(
+                                root_key, min_start_time_millis)
 
                             # This only enqueues a deferred cleanup item, so
                             # transactionality with marking the job cleaned is
diff -rupN coursebuilder_1.7.0/scripts/common.sh coursebuilder/scripts/common.sh
--- coursebuilder_1.7.0/scripts/common.sh	2014-10-10 11:33:52.000000000 -0700
+++ coursebuilder/scripts/common.sh	2015-06-26 06:55:51.653482849 -0700
@@ -157,18 +157,21 @@ if need_install karma_lib 'jasmine-jquer
 fi
 
 DISTRIBUTED_LIBS="\\
+  appengine-mapreduce-0.8.2.zip \\
   babel-0.9.6.zip \\
   gaepytz-2011h.zip \\
   inputex-3.1.0.zip \\
   yui_2in3-2.9.0.zip \\
   yui_3.6.0.zip \\
   google-api-python-client-1.1.zip \\
+  GoogleAppEngineCloudStorageClient-1.9.15.0.zip \\
+  GoogleAppEnginePipeline-1.9.17.0.zip \\
+  Graphy-1.0.0.zip \\
   pyparsing-1.5.7.zip \\
   html5lib-0.95.zip \\
   httplib2-0.8.zip \\
   python-gflags-2.0.zip \\
   mrs-mapreduce-0.9.zip \\
-  mapreduce-r645.zip \\
   markdown-2.5.zip \\
   crossfilter-1.3.7.zip \\
   d3-3.4.3.zip \\
@@ -177,6 +180,7 @@ DISTRIBUTED_LIBS="\\
   mathjax-2.3.0.zip \\
   mathjax-fonts-2.3.0.zip \\
   codemirror-4.5.0.zip \\
+  simplejson-3.7.1.zip \\
 "
 
 echo Using third party Python packages from \$DISTRIBUTED_LIBS_DIR
diff -rupN coursebuilder_1.7.0/tests/functional/actions.py coursebuilder/tests/functional/actions.py
--- coursebuilder_1.7.0/tests/functional/actions.py	2014-10-10 11:33:52.000000000 -0700
+++ coursebuilder/tests/functional/actions.py	2015-06-26 06:48:38.737500298 -0700
@@ -122,12 +122,55 @@ class OverriddenEnvironment(object):
 
     def __enter__(self):
         courses.Course.get_environ = self._get_environ
+        return self
 
     def __exit__(self, *unused_exception_info):
         courses.Course.get_environ = self._old_get_environ
         return False
 
 
+class PreserveOsEnvironDebugMode(object):
+    """Saves and restores os.environ['SERVER_SOFTWARE'] to retain debug mode.
+
+    TODO(mgainer): This can be removed once auto-backup CL is committed.
+    (That CL has a change to separate out the importation of tools.etl.remote
+    so that that module is included only in production)
+
+    When certain libraries are loaded (specifically the remote access API as
+    used by tools/etl/etl.py), the os.environ variable SERVER_SOFTWARE is
+    modified from a value that indicates a development/unit-test environment
+    to a value that indicates a production environment.  This class is meant
+    to wrap calls to etl.main() so that this value is saved and restored so
+    that the call to etl.main() does not affect the calling test or subsequent
+    tests using the same environment.  This is particularly a problem for
+    tests which also use map/reduce.  The cloud storage API relies on the
+    value of this environment variable to determine whether to try to contact
+    production servers in Borg or to run locally.
+
+    Usage:
+
+    def test_foo(self):
+        do_some_stuff()
+        with PreserveOsEnvironDebugMode():
+           etl.main( ..... args ..... )
+        self.execute_all_deferred_tasks()
+    """
+
+    def __init__(self):
+        self._save_mode = None
+
+    def __enter__(self):
+        self._save_mode = os.environ.get('SERVER_SOFTWARE')
+        return self
+
+    def __exit__(self, *unused_exception_info):
+        if self._save_mode is None:
+            if 'SERVER_SOFTWARE' in os.environ:
+                del os.environ['SERVER_SOFTWARE']
+        else:
+            os.environ['SERVER_SOFTWARE'] = self._save_mode
+
+
 class TestBase(suite.AppEngineTestBase):
     """Contains methods common to all functional tests."""
 
diff -rupN coursebuilder_1.7.0/tests/functional/model_analytics.py coursebuilder/tests/functional/model_analytics.py
--- coursebuilder_1.7.0/tests/functional/model_analytics.py	2014-10-10 11:33:52.000000000 -0700
+++ coursebuilder/tests/functional/model_analytics.py	2015-06-26 06:48:38.737500298 -0700
@@ -21,12 +21,14 @@ import datetime
 import os
 import time
 
+import cloudstorage
+
 import actions
 from actions import assert_contains
 from actions import assert_does_not_contain
 from actions import assert_equals
-from mapreduce.lib.pipeline import models as pipeline_models
-from mapreduce.lib.pipeline import pipeline
+from pipeline import models as pipeline_models
+from pipeline import pipeline
 
 import appengine_config
 from common import utils as common_utils
@@ -43,7 +45,6 @@ from modules.data_source_providers impor
 from modules.data_source_providers import synchronous_providers
 from modules.mapreduce import mapreduce_module
 
-from google.appengine.api import files
 from google.appengine.ext import db
 
 
@@ -646,22 +647,22 @@ class CronCleanupTest(actions.TestBase):
         with common_utils.Namespace('ns_' + course_name):
             return len(pipeline.get_root_list()['pipelines'])
 
-    def _get_blobstore_paths(self, course_name):
+    def _get_cloudstore_paths(self, course_name):
         ret = set()
         with common_utils.Namespace('ns_' + course_name):
             for state in pipeline.get_root_list()['pipelines']:
                 root_key = db.Key.from_path(
                     pipeline_models._PipelineRecord.kind(), state['pipelineId'])
                 paths = (mapreduce_module.CronMapreduceCleanupHandler
-                         ._collect_blobstore_paths(root_key))
+                         ._collect_cloudstore_paths(root_key))
                 ret = ret.union(paths)
         return ret
 
-    def _assert_blobstore_paths_removed(self, course_name, paths):
+    def _assert_cloudstore_paths_removed(self, course_name, paths):
         with common_utils.Namespace('ns_' + course_name):
             for path in paths:
-                with self.assertRaises(files.FinalizationError):
-                    files.open(path)
+                with self.assertRaises(cloudstorage.NotFoundError):
+                    cloudstorage.open(path)
 
     def _force_finalize(self, job):
         # For reasons that I do not grok, running the deferred task list
@@ -684,7 +685,8 @@ class CronCleanupTest(actions.TestBase):
         self.assertEquals(400, response.status_int)
 
     def test_admin_cleanup_gets_200_ok(self):
-        response = self.get('/cron/mapreduce/cleanup', expect_errors=True)
+        response = self.get('/cron/mapreduce/cleanup', expect_errors=True,
+                            headers={'X-AppEngine-Cron': 'True'})
         self.assertEquals(200, response.status_int)
 
     def test_no_jobs_no_cleanup(self):
@@ -745,12 +747,12 @@ class CronCleanupTest(actions.TestBase):
 
         self.assertEquals(1, self._get_num_root_jobs(COURSE_ONE))
         self.assertEquals(1, self._clean_jobs(datetime.timedelta(seconds=0)))
-        paths = self._get_blobstore_paths(COURSE_ONE)
-        self.assertEquals(8, len(paths))
+        paths = self._get_cloudstore_paths(COURSE_ONE)
+        self.assertEquals(6, len(paths))
 
         self.execute_all_deferred_tasks()  # Run deferred deletion task.
         self.assertEquals(0, self._get_num_root_jobs(COURSE_ONE))
-        self._assert_blobstore_paths_removed(COURSE_ONE, paths)
+        self._assert_cloudstore_paths_removed(COURSE_ONE, paths)
 
     def test_multiple_runs_cleaned(self):
         mapper = rest_providers.LabelsOnStudentsGenerator(self.course_one)
@@ -760,12 +762,12 @@ class CronCleanupTest(actions.TestBase):
 
         self.assertEquals(3, self._get_num_root_jobs(COURSE_ONE))
         self.assertEquals(3, self._clean_jobs(datetime.timedelta(seconds=0)))
-        paths = self._get_blobstore_paths(COURSE_ONE)
-        self.assertEquals(24, len(paths))
+        paths = self._get_cloudstore_paths(COURSE_ONE)
+        self.assertEquals(18, len(paths))
 
         self.execute_all_deferred_tasks()  # Run deferred deletion task.
         self.assertEquals(0, self._get_num_root_jobs(COURSE_ONE))
-        self._assert_blobstore_paths_removed(COURSE_ONE, paths)
+        self._assert_cloudstore_paths_removed(COURSE_ONE, paths)
 
     def test_cleanup_modifies_incomplete_status(self):
         mapper = rest_providers.LabelsOnStudentsGenerator(self.course_one)
@@ -797,19 +799,19 @@ class CronCleanupTest(actions.TestBase):
             self.execute_all_deferred_tasks()
 
         self.assertEquals(2, self._get_num_root_jobs(COURSE_ONE))
-        course_one_paths = self._get_blobstore_paths(COURSE_ONE)
-        self.assertEquals(16, len(course_one_paths))
+        course_one_paths = self._get_cloudstore_paths(COURSE_ONE)
+        self.assertEquals(12, len(course_one_paths))
         self.assertEquals(2, self._get_num_root_jobs(COURSE_TWO))
-        course_two_paths = self._get_blobstore_paths(COURSE_TWO)
-        self.assertEquals(16, len(course_two_paths))
+        course_two_paths = self._get_cloudstore_paths(COURSE_TWO)
+        self.assertEquals(12, len(course_two_paths))
 
         self.assertEquals(4, self._clean_jobs(datetime.timedelta(seconds=0)))
 
         self.execute_all_deferred_tasks()  # Run deferred deletion task.
         self.assertEquals(0, self._get_num_root_jobs(COURSE_ONE))
         self.assertEquals(0, self._get_num_root_jobs(COURSE_TWO))
-        self._assert_blobstore_paths_removed(COURSE_ONE, course_one_paths)
-        self._assert_blobstore_paths_removed(COURSE_TWO, course_two_paths)
+        self._assert_cloudstore_paths_removed(COURSE_ONE, course_one_paths)
+        self._assert_cloudstore_paths_removed(COURSE_TWO, course_two_paths)
 
     def test_cleanup_handler(self):
         mapper = rest_providers.LabelsOnStudentsGenerator(self.course_one)
@@ -824,7 +826,8 @@ class CronCleanupTest(actions.TestBase):
         # Note that since the actual handler uses a max time limit of
         # a few days, we need to set up a canceled job which, having
         # no defined start-time will be cleaned up immediately.
-        self.get('/cron/mapreduce/cleanup')
+        self.get('/cron/mapreduce/cleanup',
+                 headers={'X-AppEngine-Cron': 'True'})
 
         self.execute_all_deferred_tasks(iteration_limit=1)
         self.assertEquals(0, self._get_num_root_jobs(COURSE_ONE))
diff -rupN coursebuilder_1.7.0/tests/functional/module_config_test.py coursebuilder/tests/functional/module_config_test.py
--- coursebuilder_1.7.0/tests/functional/module_config_test.py	2014-10-10 11:33:52.000000000 -0700
+++ coursebuilder/tests/functional/module_config_test.py	2015-06-26 06:48:38.737500298 -0700
@@ -595,7 +595,7 @@ class ModuleIncorporationTest(TestWithTe
 
         # Touch into place the hard-coded expected set of libs so we don't
         # get spurious errors.
-        for lib in appengine_config.THIRD_PARTY_LIBS:
+        for lib in appengine_config.ALL_LIBS:
             with open(lib.file_path, 'w'):
                 pass
 
diff -rupN coursebuilder_1.7.0/tests/functional/test_classes.py coursebuilder/tests/functional/test_classes.py
--- coursebuilder_1.7.0/tests/functional/test_classes.py	2014-10-10 11:33:52.000000000 -0700
+++ coursebuilder/tests/functional/test_classes.py	2015-06-26 06:48:38.737500298 -0700
@@ -64,7 +64,8 @@ from tools import verify
 from tools.etl import etl
 from tools.etl import etl_lib
 from tools.etl import examples
-from tools.etl import remote
+with actions.PreserveOsEnvironDebugMode():
+    from tools.etl import remote
 from tools.etl import testing
 
 from google.appengine.api import memcache
diff -rupN coursebuilder_1.7.0/tests/suite.py coursebuilder/tests/suite.py
--- coursebuilder_1.7.0/tests/suite.py	2014-10-10 11:33:52.000000000 -0700
+++ coursebuilder/tests/suite.py	2015-06-26 06:48:38.737500298 -0700
@@ -215,6 +215,7 @@ class AppEngineTestBase(FunctionalTestBa
         self.testbed.init_files_stub()
         self.testbed.init_blobstore_stub()
         self.testbed.init_mail_stub()
+        self.testbed.init_app_identity_stub()
         # TODO(emichael): Fix this when an official stub is created
         self.testbed._register_stub(
             'search', simple_search_stub.SearchServiceStub())
diff -rupN coursebuilder_1.7.0/tools/etl/etl.py coursebuilder/tools/etl/etl.py
--- coursebuilder_1.7.0/tools/etl/etl.py	2014-10-10 11:33:52.000000000 -0700
+++ coursebuilder/tools/etl/etl.py	2015-06-26 06:57:44.570483251 -0700
@@ -206,12 +206,16 @@ _DELETE_DATASTORE_CONFIRMATION_INPUT = '
 # map/reduce's "_AE_... classes), or legacy types no longer required.
 _EXCLUDE_TYPES = set([
     # Map/reduce internal types:
+    '_AE_Barrier_Index',
     '_AE_MR_MapreduceState',
     '_AE_MR_ShardState',
     '_AE_Pipeline_Barrier',
     '_AE_Pipeline_Record',
     '_AE_Pipeline_Slot',
     '_AE_Pipeline_Status',
+    '_AE_TokenStorage_',
+     # AppEngine internal background jobs queue
+     '_DeferredTaskEntity',
     ])
 # Function that takes one arg and returns it.
 _IDENTITY_TRANSFORM = lambda x: x
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
