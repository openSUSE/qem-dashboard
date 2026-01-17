# QEM Dashboard API (WIP draft)

## REST API

### Authentication

All writable API endpoints use previously configured access tokens for authentication. These tokens are passed with every request
via the `Authorization` header.

`GET` requests don't need `Authorization` header.

```
PUT /api/incidents
Authorization: Token configured_access_token_here
Accept: application/json
```

Authentication failures will result in a `403` response.

```
HTTP/1.1 403 Forbidden
Content-Length: 123
Content-Type: application/json
{
  "error": "Permission denied"
}
```

### JSON

The API uses the [JSON](https://tools.ietf.org/html/rfc8259) format whenever possible. Some endpoints will however
support multiple representations through content negotiation. So you should explicitly request JSON with an
`Accept: application/json` header, or you might for example receive HTML instead.

### Failures

Validation failures and the like will be signaled with a `4xx` or `5xx` response code. When possible additional details
will be included in JSON format.

```
HTTP/1.1 400 Bad Request
Content-Length: 123
Content-Type: application/json
{
  "error": "Incidents do not match the JSON schema: ..."
}
```

### Compression

All responses larger than `860` bytes will be automatically `gzip` compressed for user-agents that include an
`Accept-Encoding: gzip` header with their requests.

```
HTTP/1.1 200 Ok
Content-Length: 123
Content-Type: application/json
Vary: Accept-Encoding
Content-Encoding: gzip
...gzip binary data...
```

### Incidents

`GET /api/incidents`

All active incidents in JSON format.

**Request parameters:**

None

**Request body:**

None

**Response:**

```
HTTP/1.1 200 OK
Content-Length: 123
Content-Type: application/json
[
  {
    "number": 16860,
    "project": "SUSE:Maintenance:16860",
    "packages": ["salt", "cobbler", "spacecmd", "mgr-daemon", "spacewalk-abrt", "yum-rhn-plugin"],
    "channels": ["SUSE:SLE-12-SP4:Update"],
    "rr_number": 228241,
    "inReview": true,
    "inReviewQAM": true,
    "approved": false,
    "emu": true,
    "isActive": true,
    "embargoed": false,
    "priority": 500
  },
  ...
]
```

---

`GET /api/incidents/<incident_number>`

Get a specific active incident in JSON format.

**Request parameters:**

None

**Request body:**

None

**Response:**

```
HTTP/1.1 200 OK
Content-Length: 123
Content-Type: application/json
{
  "number": 16860,
  "project": "SUSE:Maintenance:16860",
  "packages": ["salt", "cobbler", "spacecmd", "mgr-daemon", "spacewalk-abrt", "yum-rhn-plugin"],
  "channels": ["SUSE:SLE-12-SP4:Update"],
  "rr_number": 228241,
  "inReview": true,
  "inReviewQAM": true,
  "approved": false,
  "emu": true,
  "isActive": true,
  "embargoed": false,
  "priority": 500
}
```

---

`PATCH /api/incidents`

Update incident data from SMELT. Old incidents that are no longer included will be considered inactive.

**Request parameters:**

None

**Request body:**

```
[
  {
    "number": 16860,
    "project": "SUSE:Maintenance:16860",
    "packages": ["salt", "cobbler", "spacecmd", "mgr-daemon", "spacewalk-abrt", "yum-rhn-plugin"],
    "channels": ["SUSE:SLE-12-SP4:Update"],
    "rr_number": null,
    "inReview": true,
    "inReviewQAM": true,
    "approved": false,
    "emu": true,
    "isActive": true,
    "embargoed": false,
    "priority": 500
  },
  ...
]
```

**Response:**

```
HTTP/1.1 200 OK
Content-Length: 123
Content-Type: application/json
{
  "message": "Ok"
}
```

`PATCH /api/incidents/<incident_number>`

Update a specific incident with data from SMELT. All other incidents will not be affected.

**Request parameters:**

None

**Request body:**

```
{
  "number": 16860,
  "project": "SUSE:Maintenance:16860",
  "packages": ["salt", "cobbler", "spacecmd", "mgr-daemon", "spacewalk-abrt", "yum-rhn-plugin"],
  "channels": ["SUSE:SLE-12-SP4:Update"],
  "rr_number": null,
  "inReview": true,
  "inReviewQAM": true,
  "approved": false,
  "emu": true,
  "isActive": true,
  "embargoed": false,
  "priority": 500
}
```

**Response:**

```
HTTP/1.1 200 OK
Content-Length: 123
Content-Type: application/json
{
  "message": "Ok"
}
```

### Incident openQA settings

`GET /api/incident_settings/<incident_number>`

Get incident openQA settings.

**Request parameters:**

None

**Request body:**

None

**Response**

```
[
  {
    "id": 7,
    "incident": 16860,
    "version": "12-SP2",
    "flavor": "Server-DVD-HA-Incidents-Install",
    "arch": "x86_64",
    "withAggregate": true,
    "settings": {
      "DISTRI": "sle",
      "VERSION": "12-SP2"
      ...
    }
  },
  ...
]
```

---

`PUT /api/incident_settings`

Add or update incident openQA settings. Returns the internal dashboard id required for the creation of jobs.

**Request parameters:**

None

**Request body:**

```
{
  "incident": 16860,
  "version": "12-SP2",
  "flavor": "Server-DVD-HA-Incidents-Install",
  "arch": "x86_64",
  "withAggregate": true,
  "settings": {
    "DISTRI": "sle",
    "VERSION": "12-SP2"
    ...
  }
}
```

**Response:**

```
HTTP/1.1 200 OK
Content-Length: 123
Content-Type: application/json
{
  "message": "Ok",
  "id": 7
}
```

### Update openQA settings

`GET /api/update_settings/<incident_number>`

Get update openQA settings.

**Request parameters:**

None

**Request body:**

None

**Response**

```
[
  {
    "id": 23,
    "incidents": [16861],
    "product": "SLES-15-GA",
    "arch": "x86_64",
    "build": "20201107-1",
    "repohash": "d5815a9f8aa482ec8288508da27a9d36",
    "settings": {
      "DISTRI": "sle",
      "VERSION": "15-SP2"
      ...
    }
  },
  ...
]
```

---

`GET /api/update_settings`

Get update openQA settings matching the given search parameters. Newest settings first.

**Request parameters:**

* `product` (required): Settings need to be for this product.

* `arch` (required): Settings need to be for this architecture.

* `limit` (optional): Limit the number of results, defaults to `50`.

```
GET /api/update_settings?product=SLES-15-GA&arch=x86_64
Authorization: Token configured_access_token_here
Accept: application/json
```

**Request body:**

None

**Response**

```
[
  {
    "id": 1,
    "incidents": [16861],
    "product": "SLES-15-GA",
    "arch": "x86_64",
    "build": "20201107-1",
    "repohash": "d5815a9f8aa482ec8288508da27a9d36",
    "settings": {
      "DISTRI": "sle",
      "VERSION": "15-SP2"
      ...
    }
  },
  ...
]
```

---

`PUT /api/update_settings`

Add update openQA settings. Returns the internal dashboard id required for the creation of jobs.

**Request parameters:**

None

**Request body:**

```
{
  "incidents": [16861],
  "product": "SLES-15-GA",
  "arch": "x86_64",
  "build": "20201107-1",
  "repohash": "d5815a9f8aa482ec8288508da27a9d36",
  "settings": {
    "DISTRI": "sle",
    "VERSION": "15-SP2"
    ...
  }
}
```

**Response:**

```
HTTP/1.1 200 OK
Content-Length: 123
Content-Type: application/json
{
  "message": "Ok",
  "id": 23
}
```

### openQA jobs

`GET /api/jobs/<job_id>`

Get openQA job.

**Request parameters:**

None

**Request body:**

None

**Response**

```
{
  "job_id": 4953193,
  "incident_settings": null,
  "update_settings": 23,
  "name": "mau-webserver@64bit",
  "job_group": "Maintenance: SLE 12 SP5 Incidents",
  "group_id": 282,
  "status": "passed",
  "distri": "sle",
  "flavor": "Server-DVD-Incidents",
  "arch": "x86_64",
  "version": "12-SP5",
  "build": ":16860:wpa_supplicant",
  "obsolete": false
}
```

---

`PUT /api/jobs`

Add or update openQA job. The job is required to reference either `incident_settings` or `update_settings` with their
respective internal dashboard id.

**Request parameters:**

None

**Request body:**

```
{
  "job_id": 4953193,
  "incident_settings": null,
  "update_settings": 23,
  "name": "mau-webserver@64bit",
  "job_group": "Maintenance: SLE 12 SP5 Incidents",
  "group_id": 282,
  "status": "passed",
  "distri": "sle",
  "flavor": "Server-DVD-Incidents",
  "arch": "x86_64",
  "version": "12-SP5",
  "build": ":16860:wpa_supplicant"
}
```

**Response:**

```
HTTP/1.1 200 OK
Content-Length: 123
Content-Type: application/json
{
  "message": "Ok"
}
```

---

`PATCH /api/jobs/<job_id>`

Update job information that commonly changes during its lifetime.

**Request parameters:**

None

**Request body:**

```
{
  "obsolete": true
}
```

**Response:**

```
HTTP/1.1 200 OK
Content-Length: 123
Content-Type: application/json
{
  "message": "Ok"
}
```

---

`GET /api/jobs/incident/<incident_settings>`

Get openQA jobs by incident_settings.

**Request parameters:**

None

**Request body:**

None

**Response:**

```
[
  {
    "job_id": 4953193,
    "incident_settings": 23,
    "update_settings": null,
    "name": "mau-webserver@64bit",
    "job_group": "Maintenance: SLE 12 SP5 Incidents",
    "group_id": 282,
    "status": "passed",
    "distri": "sle",
    "flavor": "Server-DVD-Incidents",
    "arch": "x86_64",
    "version": "12-SP5",
    "build": ":16860:wpa_supplicant"
  },
  ...
]
```

---

`GET /api/jobs/update/<update_settings>`

Get openQA jobs by update_settings.

**Request parameters:**

None

**Request body:**

None

**Response:**

```
[
  {
    "job_id": 4953193,
    "incident_settings": null,
    "update_settings": 23,
    "name": "mau-webserver@64bit",
    "job_group": "Maintenance: SLE 12 SP5 Incidents",
    "group_id": 282,
    "status": "passed",
    "distri": "sle",
    "flavor": "Server-DVD-Incidents",
    "arch": "x86_64",
    "version": "12-SP5",
    "build": ":16860:wpa_supplicant"
  },
  ...
]
```

#### Remarks on openQA jobs
`GET /api/jobs/<job_id>/remarks`

List remarks on an openQA job.

**Request parameters:**

None

**Request body:**

None

**Response:**

```
{
  "remarks": [
    {
      "text": "foo",
      "incident": 1234
    },
    {
      "text": "bar",
      "incident": 5678
    }
    ...
  ]
}
```

---

`PATCH /api/jobs/<job_id>/remarks`

Creates or updates a remark on an openQA job, possibly incident-specific.

Only one remark can exist per incident.

**Request parameters:**

* `incident_number` (optional): The incident number if the remark is incident-specific.

* `text` (optional): The remark text, defaults to an empty text.

**Request body:**

None

**Response:**

```
{
  "message": "Ok"
}
```
