## 1.2.1 [2011-02-01] Michael Granger <ged@FaerieMUD.org>

Bugfixes:

* Update Hoe dependency
* Consistency fixes.
* Fixed the add_include_dirs call, describe the 'ci' task
* Updated hoe dependency

## 1.2.0 [2011-01-05] Michael Granger <ged@FaerieMUD.org>

Removed old attributes:

* 'hg_repo', the task now just uses the Mercurial 'default' or 'default-push' path.
* 'hg_release_branch', which wasn't really used as a branch

Enhancements:

* hoe-mercurial now injects itself as a dev dependency.


## 1.1.1 [2011-01-04] Michael Granger <ged@FaerieMUD.org>

Simplified the hg:checkin task.


## 1.1.0 [2010-12-14] Michael Granger <ged@FaerieMUD.org>

Initial release after forking from hoe-hg.


