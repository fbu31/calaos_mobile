#include "CalaosOsAPI.h"
#include <QStringBuilder>

#define TOKEN_FILE  "/run/calaos-ct.token"

CalaosOsAPI::CalaosOsAPI(QNetworkAccessManager *nm, QObject *parent):
    QObject(parent),
    netManager(nm)
{
    if (!netManager)
        netManager = new QNetworkAccessManager(this);

    QFile file(TOKEN_FILE);
    if (file.open(QIODevice::ReadOnly | QIODevice::Text))
        token = file.readAll().trimmed();
    else
        qWarning() << "unable to read " << TOKEN_FILE;

    calaosAddr = "http://127.0.0.1:8000";
}

CalaosOsAPI::~CalaosOsAPI()
{
}

void CalaosOsAPI::rebootMachine(std::function<void (bool)> callback)
{
    doPost("/api/system/reboot", {}, callback);
}

void CalaosOsAPI::restartApp(std::function<void (bool)> callback)
{
    doPost("/api/system/restart", {}, callback);
}

void CalaosOsAPI::getFsStatus(std::function<void (bool, const QJsonObject &)> callback)
{
    doGet("/api/system/fs_status", callback);
}

void CalaosOsAPI::rollbackSnapshot(std::function<void (bool)> callback)
{
    doPost("/api/system/rollback_snapshot", {}, callback);
}

void CalaosOsAPI::listInstallDevices(std::function<void (bool, const QJsonObject &)> callback)
{
    doGet("/api/system/install/list_devices", callback);
}

void CalaosOsAPI::startInstallation(QString device, std::function<void (bool)> callbackFinished, std::function<void (QString)> callbackStdout)
{
    AsyncJobs *jobs = new AsyncJobs(this);

    jobs->append(new AsyncJob([this, device, callbackStdout](AsyncJob *job, const QVariant &)
                              {
                                  lastError.clear();
                                  QString url = calaosAddr % "/system/install/start";

                                  NetworkRequest *n = new NetworkRequest(url, NetworkRequest::HttpPost, this);
                                  n->setNetManager(netManager);
                                  n->setCustomHeader("Authorization", QStringLiteral("bearer %1").arg(token));
                                  n->setResultType(NetworkRequest::TypeJson);

                                  QJsonObject d = {{ "device", device }};
                                  QJsonDocument doc(d);
                                  n->setPostData(doc.toJson(QJsonDocument::Compact));

                                  //TODO: connect to readyRead signal to get data for callbackStdout
                                  connect(n, &NetworkRequest::dataReadyRead, this, [callbackStdout](const QByteArray &data)
                                          {
                                              callbackStdout(QString::fromUtf8(data));
                                          });

                                  connect(n, &NetworkRequest::finishedJson, this, [this, n, job](int success, const QJsonDocument &jdoc)
                                          {
                                              n->deleteLater();

                                              if (success == NetworkRequest::RequestSuccess)
                                              {
                                                  job->emitSuccess();
                                              }
                                              else
                                              {
                                                  checkErrors(jdoc, n);
                                                  job->emitFailed();
                                              }
                                          });

                                  if (!n->start())
                                  {
                                      delete n;
                                      lastError = "Failed to start network request";
                                      job->emitFailed();
                                  }
                              }));

    connect(jobs, &AsyncJobs::failed, this, [callbackFinished](AsyncJob *)
            {
                callbackFinished(false);
            });

    connect(jobs, &AsyncJobs::finished, this, [callbackFinished](const QVariant &)
            {
                callbackFinished(true);
            });

    jobs->start();
}

void CalaosOsAPI::checkErrors(const QJsonDocument &jdoc, NetworkRequest *n)
{
    QJsonObject jobj = jdoc.object();
    if (jobj["error"].toBool())
    {
        lastError.append(jobj["msg"].toString());
    }

    if (n)
        lastError.append(n->getLastError());
}

void CalaosOsAPI::doPost(QString apiPath, const QByteArray &postData, std::function<void (bool)> callback)
{
    AsyncJobs *jobs = new AsyncJobs(this);

    jobs->append(new AsyncJob([this, apiPath, postData](AsyncJob *job, const QVariant &)
                              {
                                  lastError.clear();
                                  QString url = calaosAddr % apiPath;

                                  NetworkRequest *n = new NetworkRequest(url, NetworkRequest::HttpPost, this);
                                  n->setNetManager(netManager);
                                  n->setCustomHeader("Authorization", QStringLiteral("bearer %1").arg(token));
                                  n->setResultType(NetworkRequest::TypeJson);
                                  n->setPostData(postData);

                                  connect(n, &NetworkRequest::finishedJson, this, [this, n, job](int success, const QJsonDocument &jdoc)
                                          {
                                              n->deleteLater();

                                              if (success == NetworkRequest::RequestSuccess)
                                              {
                                                  job->emitSuccess();
                                              }
                                              else
                                              {
                                                  checkErrors(jdoc, n);
                                                  job->emitFailed();
                                              }
                                          });

                                  if (!n->start())
                                  {
                                      delete n;
                                      lastError = "Failed to start network request";
                                      job->emitFailed();
                                  }
                              }));

    connect(jobs, &AsyncJobs::failed, this, [callback](AsyncJob *)
            {
                callback(false);
            });

    connect(jobs, &AsyncJobs::finished, this, [callback](const QVariant &)
            {
                callback(true);
            });

    jobs->start();
}

void CalaosOsAPI::doGet(QString apiPath, std::function<void (bool, const QJsonObject &)> callback)
{
    AsyncJobs *jobs = new AsyncJobs(this);

    jobs->append(new AsyncJob([this, apiPath](AsyncJob *job, const QVariant &)
                              {
                                  lastError.clear();
                                  QString url = calaosAddr % apiPath;

                                  NetworkRequest *n = new NetworkRequest(url, NetworkRequest::HttpGet, this);
                                  n->setNetManager(netManager);
                                  n->setCustomHeader("Authorization", QStringLiteral("bearer %1").arg(token));
                                  n->setResultType(NetworkRequest::TypeJson);

                                  connect(n, &NetworkRequest::finishedJson, this, [this, n, job](int success, const QJsonDocument &jdoc)
                                          {
                                              n->deleteLater();

                                              if (success == NetworkRequest::RequestSuccess)
                                              {
                                                  QJsonObject jobj = jdoc.object();
                                                  if (jobj["error"].toBool())
                                                  {
                                                      checkErrors(jdoc, n);
                                                      job->emitFailed();
                                                  }
                                                  else
                                                  {
                                                      QJsonParseError err;
                                                      QJsonDocument doc;

                                                      doc = QJsonDocument::fromJson(jobj["out"].toString().toUtf8(), &err);
                                                      if (err.error == QJsonParseError::NoError)
                                                      {
                                                          auto e = "JSON parse error " + err.errorString() + " at offset: " + QString::number(err.offset);
                                                          lastError.append(e);
                                                          job->emitFailed();
                                                      }
                                                      else
                                                      {
                                                          job->emitSuccess(doc.object());
                                                      }
                                                  }
                                              }
                                              else
                                              {
                                                  checkErrors(jdoc, n);
                                                  job->emitFailed();
                                              }
                                          });

                                  if (!n->start())
                                  {
                                      delete n;
                                      lastError = "Failed to start network request";
                                      job->emitFailed();
                                  }
                              }));

    connect(jobs, &AsyncJobs::failed, this, [callback](AsyncJob *)
            {
                callback(false, {});
            });

    connect(jobs, &AsyncJobs::finished, this, [callback](const QVariant &data)
            {
                callback(true, data.toJsonObject());
            });

    jobs->start();
}

