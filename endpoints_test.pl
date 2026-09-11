#!/usr/bin/perl
use strict;
use warnings;
use HTTP::Tiny;   # core module, ships with Perl - no install needed
use JSON::PP;     # core module, ships with Perl - no install needed

my $BASE_URL = 'http://localhost:3000';
my $http = HTTP::Tiny->new;
my $json = JSON::PP->new->utf8;

my $pass_count = 0;
my $fail_count = 0;

sub section {
    my ($title) = @_;
    print "\n", "=" x 60, "\n";
    print "$title\n";
    print "=" x 60, "\n";
}

sub check {
    my ($label, $condition) = @_;
    if ($condition) {
        print "PASS - $label\n";
        $pass_count++;
    } else {
        print "FAIL - $label\n";
        $fail_count++;
    }
}

sub show {
    my ($res) = @_;
    print "Status: $res->{status}\n";
    print "Body:   ", ($res->{content} // '(empty)'), "\n";
}

sub auth_headers {
    my ($token, $with_json) = @_;
    my %h = ( 'Authorization' => "Bearer $token" );
    $h{'Content-Type'} = 'application/json' if $with_json;
    return \%h;
}

sub register_and_login {
    my $email    = 'test' . time() . '_' . int(rand(100000)) . '@example.com';
    my $password = 'password123';
    my $res = $http->post(
        "$BASE_URL/auth/register",
        {
            headers => { 'Content-Type' => 'application/json' },
            content => $json->encode({ email => $email, password => $password }),
        }
    );
    return undef unless $res->{status} == 201;
    my $data = eval { $json->decode($res->{content}) };
    return $data ? $data->{accessToken} : undef;
}

# ---------------------------------------------------------------
section("0. Register two users (user A = primary, user B = for isolation checks)");
# ---------------------------------------------------------------
my $token_a = register_and_login();
check("user A registered and got accessToken", $token_a ? 1 : 0);
die "\nCannot continue without user A token.\n" unless $token_a;

my $token_b = register_and_login();
check("user B registered and got accessToken", $token_b ? 1 : 0);

# ---------------------------------------------------------------
# Generic CRUD tester for a resource mounted at /health/<path>
#
# name            - human readable label, e.g. "Weights"
# path            - url path under /health, e.g. "weights"
# create_payload  - hashref sent on POST (valid)
# invalid_payload - hashref sent on POST that should trigger a 400
# patch_payload   - hashref sent on PATCH
# patch_field     - field name to verify after PATCH
# patch_value     - expected value of patch_field after PATCH
# list_query      - optional query string to smoke-test filtering, e.g. "site=waist"
# ---------------------------------------------------------------
sub build_multipart {
    my (%fields) = @_;
    my $boundary = 'PerlFormBoundary' . int(rand(1e9));
    my $body = '';
    for my $name (keys %fields) {
        my $f = $fields{$name};
        $body .= "--$boundary\r\n";
        if (exists $f->{filename}) {
            $body .= "Content-Disposition: form-data; name=\"$name\"; filename=\"$f->{filename}\"\r\n";
            $body .= "Content-Type: $f->{content_type}\r\n\r\n";
            $body .= $f->{content} . "\r\n";
        } else {
            $body .= "Content-Disposition: form-data; name=\"$name\"\r\n\r\n";
            $body .= $f->{value} . "\r\n";
        }
    }
    $body .= "--$boundary--\r\n";
    return ($body, $boundary);
}


sub test_resource {
    my (%args) = @_;
    my $name            = $args{name};
    my $path             = "health/$args{path}";
    my $create_payload   = $args{create_payload};
    my $invalid_payload  = $args{invalid_payload};
    my $patch_payload    = $args{patch_payload};
    my $patch_field      = $args{patch_field};
    my $patch_value      = $args{patch_value};
    my $list_query       = $args{list_query};

    section("$name: POST /$path with invalid body (expect 400)");
    if ($invalid_payload) {
        my $bad_res = $http->post(
            "$BASE_URL/$path",
            {
                headers => auth_headers($token_a, 1),
                content => $json->encode($invalid_payload),
            }
        );
        show($bad_res);
        check("$name POST with missing required field returns 400", $bad_res->{status} == 400);
    } else {
        print "(skipped - no invalid payload defined)\n";
    }

    section("$name: POST /$path (create, valid)");
    my $create_res = $http->post(
        "$BASE_URL/$path",
        {
            headers => auth_headers($token_a, 1),
            content => $json->encode($create_payload),
        }
    );
    show($create_res);
    check("$name create returns 201", $create_res->{status} == 201);

    my $id;
    if ($create_res->{status} == 201) {
        my $data = eval { $json->decode($create_res->{content}) };
        $id = $data->{id} if $data;
        check("$name create response includes id", $id ? 1 : 0);
    }
    return unless $id;

    section("$name: GET /$path (list, bare array)");
    my $list_res = $http->get(
        "$BASE_URL/$path",
        { headers => auth_headers($token_a, 0) }
    );
    show($list_res);
    check("$name list returns 200", $list_res->{status} == 200);
    if ($list_res->{status} == 200) {
        my $data = eval { $json->decode($list_res->{content}) };
        check("$name list response is a bare JSON array", ref($data) eq 'ARRAY');
        my $found = ref($data) eq 'ARRAY' && grep { ($_->{id} // '') eq $id } @$data;
        check("$name list contains newly created entry", $found ? 1 : 0);
    }

    if ($list_query) {
        section("$name: GET /$path?$list_query (filter smoke test)");
        my $filtered_res = $http->get(
            "$BASE_URL/$path?$list_query",
            { headers => auth_headers($token_a, 0) }
        );
        show($filtered_res);
        check("$name filtered list returns 200", $filtered_res->{status} == 200);
    }

    section("$name: PATCH /$path/$id (update)");
    my $patch_res = $http->request(
        'PATCH',
        "$BASE_URL/$path/$id",
        {
            headers => auth_headers($token_a, 1),
            content => $json->encode($patch_payload),
        }
    );
    show($patch_res);
    check("$name PATCH returns 200", $patch_res->{status} == 200);
    if ($patch_res->{status} == 200 && defined $patch_field) {
        my $data = eval { $json->decode($patch_res->{content}) };
        check("$name PATCH actually updated $patch_field",
            $data && (($data->{$patch_field} // '') eq $patch_value));
    }

    section("$name: Negative - no auth token at all");
    my $no_auth_res = $http->get("$BASE_URL/$path");
    show($no_auth_res);
    check("$name GET list with no auth returns 401", $no_auth_res->{status} == 401);

    if ($token_b) {
        section("$name: Isolation - user B cannot see/edit/delete user A's entry");
        my $b_get_res = $http->get(
            "$BASE_URL/$path",
            { headers => auth_headers($token_b, 0) }
        );
        show($b_get_res);
        if ($b_get_res->{status} == 200) {
            my $data = eval { $json->decode($b_get_res->{content}) };
            my $leaked = ref($data) eq 'ARRAY' && grep { ($_->{id} // '') eq $id } @$data;
            check("$name user B's list does not contain user A's entry", !$leaked);
        }

        my $b_patch_res = $http->request(
            'PATCH',
            "$BASE_URL/$path/$id",
            {
                headers => auth_headers($token_b, 1),
                content => $json->encode($patch_payload),
            }
        );
        show($b_patch_res);
        check("$name user B PATCH on user A's entry returns 404", $b_patch_res->{status} == 404);

        my $b_delete_res = $http->request(
            'DELETE',
            "$BASE_URL/$path/$id",
            { headers => auth_headers($token_b, 0) }
        );
        show($b_delete_res);
        check("$name user B DELETE on user A's entry returns 404", $b_delete_res->{status} == 404);
    }

    section("$name: DELETE /$path/$id (as owner, user A)");
    my $delete_res = $http->request(
        'DELETE',
        "$BASE_URL/$path/$id",
        { headers => auth_headers($token_a, 0) }
    );
    show($delete_res);
    check("$name DELETE returns 204", $delete_res->{status} == 204);

    section("$name: PATCH /$path/$id after delete (should 404)");
    my $after_delete_res = $http->request(
        'PATCH',
        "$BASE_URL/$path/$id",
        {
            headers => auth_headers($token_a, 1),
            content => $json->encode($patch_payload),
        }
    );
    show($after_delete_res);
    check("$name PATCH after delete returns 404", $after_delete_res->{status} == 404);
}

# ---------------------------------------------------------------
# 1. Weights
# ---------------------------------------------------------------
test_resource(
    name            => 'Weights',
    path            => 'weights',
    create_payload  => { date => '2026-09-01T00:00:00.000Z', kg => 72.5 },
    invalid_payload => { date => '2026-09-01T00:00:00.000Z' },  # missing kg
    patch_payload   => { kg => 71.8 },
    patch_field     => 'kg',
    patch_value     => 71.8,
    list_query      => 'from=2026-01-01&to=2026-12-31',
);

# ---------------------------------------------------------------
# 2. Measurements
# ---------------------------------------------------------------
test_resource(
    name            => 'Measurements',
    path            => 'measurements',
    create_payload  => { date => '2026-09-01T00:00:00.000Z', site => 'waist', valueCm => 85.0 },
    invalid_payload => { date => '2026-09-01T00:00:00.000Z', valueCm => 85.0 },  # missing site
    patch_payload   => { valueCm => 84.2 },
    patch_field     => 'valueCm',
    patch_value     => 84.2,
    list_query      => 'site=waist',
);

# ---------------------------------------------------------------
# 3. Sleep
# ---------------------------------------------------------------
test_resource(
    name            => 'Sleep',
    path            => 'sleep',
    create_payload  => {
        date            => '2026-09-01T00:00:00.000Z',
        durationMinutes => 420,
        quality         => 4,
        interruptions   => 1,
    },
    invalid_payload => { date => '2026-09-01T00:00:00.000Z' },  # missing durationMinutes
    patch_payload   => { quality => 5 },
    patch_field     => 'quality',
    patch_value     => 5,
    list_query      => 'from=2026-01-01&to=2026-12-31',
);

# ---------------------------------------------------------------
# 4. Wellbeing
# ---------------------------------------------------------------
test_resource(
    name            => 'Wellbeing',
    path            => 'wellbeing',
    create_payload  => {
        date     => '2026-09-01T00:00:00.000Z',
        mood     => 4,
        stress   => 2,
        energy   => 3,
        soreness => 1,
        fatigue  => 2,
    },
    invalid_payload => { mood => 4 },  # missing date
    patch_payload   => { mood => 5 },
    patch_field     => 'mood',
    patch_value     => 5,
    list_query      => 'from=2026-01-01&to=2026-12-31',
);

# ---------------------------------------------------------------
# 5. Vitals (resting_heart_rate)
# ---------------------------------------------------------------
test_resource(
    name            => 'Vitals (heart rate)',
    path            => 'vitals',
    create_payload  => { kind => 'resting_heart_rate', value => 58 },
    invalid_payload => { kind => 'resting_heart_rate' },  # missing value
    patch_payload   => { value => 60 },
    patch_field     => 'value',
    patch_value     => 60,
    list_query      => 'kind=resting_heart_rate',
);

# ---------------------------------------------------------------
# 6. Vitals (blood_pressure) - separate kind-specific validation
# ---------------------------------------------------------------
section("Vitals (blood pressure): POST /health/vitals missing systolic/diastolic (expect 400)");
my $bp_bad_res = $http->post(
    "$BASE_URL/health/vitals",
    {
        headers => auth_headers($token_a, 1),
        content => $json->encode({ kind => 'blood_pressure' }),
    }
);
show($bp_bad_res);
check("blood_pressure POST missing systolic/diastolic returns 400", $bp_bad_res->{status} == 400);

section("Vitals (blood pressure): POST /health/vitals (valid)");
my $bp_res = $http->post(
    "$BASE_URL/health/vitals",
    {
        headers => auth_headers($token_a, 1),
        content => $json->encode({ kind => 'blood_pressure', systolic => 120, diastolic => 80 }),
    }
);
show($bp_res);
check("blood_pressure POST with systolic/diastolic returns 201", $bp_res->{status} == 201);
if ($bp_res->{status} == 201) {
    my $data = eval { $json->decode($bp_res->{content}) };
    check("blood_pressure entry stored correct systolic/diastolic",
        $data && $data->{systolic} == 120 && $data->{diastolic} == 80);
}

# ---------------------------------------------------------------
# 7. Medications
# ---------------------------------------------------------------
test_resource(
    name            => 'Medications',
    path            => 'medications',
    create_payload  => { name => 'Vitamin D3', isPrescription => JSON::PP::false, dosage => '1000 IU', frequency => 'daily', quantityLeft => 30 },
    invalid_payload => { dosage => '1000 IU' },  # missing name
    patch_payload   => { quantityLeft => 25 },
    patch_field     => 'quantityLeft',
    patch_value     => 25,
);

# ---------------------------------------------------------------
# 8. Appointments
# ---------------------------------------------------------------
test_resource(
    name            => 'Appointments',
    path            => 'appointments',
    create_payload  => { title => 'Dentist checkup', scheduledAt => '2026-09-15T10:00:00.000Z', provider => 'Dr. Sharma', location => 'Clinic A' },
    invalid_payload => { provider => 'Dr. Sharma' },  # missing title and scheduledAt
    patch_payload   => { title => 'Dentist checkup (rescheduled)' },
    patch_field     => 'title',
    patch_value     => 'Dentist checkup (rescheduled)',
);


# ---------------------------------------------------------------
section("9. Photos: POST /health/photos (upload)");
# ---------------------------------------------------------------
my $fake_png = "\x89PNG\r\n\x1a\n" . ("\x00" x 20);  # minimal fake binary content, good enough to test upload plumbing
my ($photo_body, $photo_boundary) = build_multipart(
    date  => { value => '2026-09-01' },
    photo => { filename => 'test.png', content_type => 'image/png', content => $fake_png },
);
my $photo_post_res = $http->request('POST', "$BASE_URL/health/photos", {
    headers => { 'Authorization' => "Bearer $token_a", 'Content-Type' => "multipart/form-data; boundary=$photo_boundary" },
    content => $photo_body,
});
show($photo_post_res);
check("Photos upload returns 201", $photo_post_res->{status} == 201);

my $photo_id;
if ($photo_post_res->{status} == 201) {
    my $data = eval { $json->decode($photo_post_res->{content}) };
    $photo_id = $data->{id} if $data;
}

section("Photos: GET /health/photos (list)");
my $photo_list_res = $http->get("$BASE_URL/health/photos", { headers => auth_headers($token_a, 0) });
show($photo_list_res);
check("Photos list returns 200", $photo_list_res->{status} == 200);

if ($photo_id) {
    section("Photos: DELETE /health/photos/:id");
    my $photo_delete_res = $http->request('DELETE', "$BASE_URL/health/photos/$photo_id", { headers => auth_headers($token_a, 0) });
    show($photo_delete_res);
    check("Photos delete returns 204", $photo_delete_res->{status} == 204);
}

# ---------------------------------------------------------------
section("10. Records: POST /health/records (upload)");
# ---------------------------------------------------------------
my $fake_pdf = "%PDF-1.4\n" . ("\x00" x 20);
my ($record_body, $record_boundary) = build_multipart(
    title  => { value => 'Blood test report' },
    record => { filename => 'test.pdf', content_type => 'application/pdf', content => $fake_pdf },
);
my $record_post_res = $http->request('POST', "$BASE_URL/health/records", {
    headers => { 'Authorization' => "Bearer $token_a", 'Content-Type' => "multipart/form-data; boundary=$record_boundary" },
    content => $record_body,
});
show($record_post_res);
check("Records upload returns 201", $record_post_res->{status} == 201);

my $record_id;
if ($record_post_res->{status} == 201) {
    my $data = eval { $json->decode($record_post_res->{content}) };
    $record_id = $data->{id} if $data;
}

section("Records: GET /health/records (list)");
my $record_list_res = $http->get("$BASE_URL/health/records", { headers => auth_headers($token_a, 0) });
show($record_list_res);
check("Records list returns 200", $record_list_res->{status} == 200);

if ($record_id) {
    section("Records: DELETE /health/records/:id");
    my $record_delete_res = $http->request('DELETE', "$BASE_URL/health/records/$record_id", { headers => auth_headers($token_a, 0) });
    show($record_delete_res);
    check("Records delete returns 204", $record_delete_res->{status} == 204);
}


# ---------------------------------------------------------------
section("11. GET /health/summary");
# ---------------------------------------------------------------
my $summary_res = $http->get("$BASE_URL/health/summary", { headers => auth_headers($token_a, 0) });
show($summary_res);
check("Summary returns 200", $summary_res->{status} == 200);
if ($summary_res->{status} == 200) {
    my $data = eval { $json->decode($summary_res->{content}) };
    check("Summary response includes latestVitals object", $data && ref($data->{latestVitals}) eq 'HASH');
}

section("Summary: negative - no token");
my $summary_no_auth_res = $http->get("$BASE_URL/health/summary");
show($summary_no_auth_res);
check("Summary with no token returns 401", $summary_no_auth_res->{status} == 401);



# ---------------------------------------------------------------
section("12. Plans: POST /fitness/plans (with nested exercises)");
# ---------------------------------------------------------------
my $plan_res = $http->post(
    "$BASE_URL/fitness/plans",
    {
        headers => auth_headers($token_a, 1),
        content => $json->encode({
            name               => 'Push Day A',
            targetMuscleGroups => ['chest', 'shoulders', 'triceps'],
            exercises          => [
                { name => 'Bench Press', order => 0, prescribedSets => 4, prescribedReps => '6-8' },
                { name => 'Overhead Press', order => 1, prescribedSets => 3, prescribedReps => '8-12' },
            ],
        }),
    }
);
show($plan_res);
check("Plans create returns 201", $plan_res->{status} == 201);

my $plan_id;
if ($plan_res->{status} == 201) {
    my $data = eval { $json->decode($plan_res->{content}) };
    $plan_id = $data->{id} if $data;
    check("Plans create response includes nested exercises array with 2 items",
        $data && ref($data->{exercises}) eq 'ARRAY' && scalar(@{$data->{exercises}}) == 2);
}

section("Plans: POST /fitness/plans with invalid body (expect 400)");
my $plan_bad_res = $http->post(
    "$BASE_URL/fitness/plans",
    {
        headers => auth_headers($token_a, 1),
        content => $json->encode({ targetMuscleGroups => ['chest'] }),  # missing name
    }
);
show($plan_bad_res);
check("Plans POST missing name returns 400", $plan_bad_res->{status} == 400);

section("Plans: GET /fitness/plans (list)");
my $plan_list_res = $http->get("$BASE_URL/fitness/plans", { headers => auth_headers($token_a, 0) });
show($plan_list_res);
check("Plans list returns 200", $plan_list_res->{status} == 200);
if ($plan_list_res->{status} == 200 && $plan_id) {
    my $data = eval { $json->decode($plan_list_res->{content}) };
    my $found = ref($data) eq 'ARRAY' && grep { ($_->{id} // '') eq $plan_id } @$data;
    check("Plans list contains newly created plan", $found ? 1 : 0);
}

if ($plan_id) {
    section("Plans: GET /fitness/plans/:id (single, with nested exercises)");
    my $plan_get_res = $http->get("$BASE_URL/fitness/plans/$plan_id", { headers => auth_headers($token_a, 0) });
    show($plan_get_res);
    check("Plans GET/:id returns 200", $plan_get_res->{status} == 200);
    if ($plan_get_res->{status} == 200) {
        my $data = eval { $json->decode($plan_get_res->{content}) };
        check("Plans GET/:id includes exercises ordered correctly",
            $data && ref($data->{exercises}) eq 'ARRAY'
            && $data->{exercises}[0]{name} eq 'Bench Press'
            && $data->{exercises}[1]{name} eq 'Overhead Press');
    }

    section("Plans: PATCH /fitness/plans/:id");
    my $plan_patch_res = $http->request('PATCH', "$BASE_URL/fitness/plans/$plan_id", {
        headers => auth_headers($token_a, 1),
        content => $json->encode({ name => 'Push Day A (updated)' }),
    });
    show($plan_patch_res);
    check("Plans PATCH returns 200", $plan_patch_res->{status} == 200);
    if ($plan_patch_res->{status} == 200) {
        my $data = eval { $json->decode($plan_patch_res->{content}) };
        check("Plans PATCH actually updated name", $data && $data->{name} eq 'Push Day A (updated)');
    }

    section("Plans: Negative - no auth token");
    my $plan_no_auth_res = $http->get("$BASE_URL/fitness/plans");
    show($plan_no_auth_res);
    check("Plans list with no auth returns 401", $plan_no_auth_res->{status} == 401);

    if ($token_b) {
        section("Plans: Isolation - user B cannot access user A's plan");
        my $plan_b_res = $http->get("$BASE_URL/fitness/plans/$plan_id", { headers => auth_headers($token_b, 0) });
        show($plan_b_res);
        check("Plans user B GET/:id on user A's plan returns 404", $plan_b_res->{status} == 404);

        my $plan_b_delete_res = $http->request('DELETE', "$BASE_URL/fitness/plans/$plan_id", { headers => auth_headers($token_b, 0) });
        show($plan_b_delete_res);
        check("Plans user B DELETE on user A's plan returns 404", $plan_b_delete_res->{status} == 404);
    }

    section("Plans: DELETE /fitness/plans/:id (as owner)");
    my $plan_delete_res = $http->request('DELETE', "$BASE_URL/fitness/plans/$plan_id", { headers => auth_headers($token_a, 0) });
    show($plan_delete_res);
    check("Plans DELETE returns 204", $plan_delete_res->{status} == 204);

    section("Plans: GET /fitness/plans/:id after delete (should 404)");
    my $plan_after_delete_res = $http->get("$BASE_URL/fitness/plans/$plan_id", { headers => auth_headers($token_a, 0) });
    show($plan_after_delete_res);
    check("Plans GET/:id after delete returns 404", $plan_after_delete_res->{status} == 404);
}



# ---------------------------------------------------------------
section("13. Sessions: POST /fitness/sessions with invalid body (expect 400)");
# ---------------------------------------------------------------
my $session_bad_res = $http->post(
    "$BASE_URL/fitness/sessions",
    {
        headers => auth_headers($token_a, 1),
        content => $json->encode({ muscles => ['chest'] }),  # missing date and title
    }
);
show($session_bad_res);
check("Sessions POST missing date/title returns 400", $session_bad_res->{status} == 400);

section("Sessions: POST /fitness/sessions (create)");
my $session_res = $http->post(
    "$BASE_URL/fitness/sessions",
    {
        headers => auth_headers($token_a, 1),
        content => $json->encode({
            date            => '2026-09-01T00:00:00.000Z',
            title           => 'Push Day A',
            muscles         => ['chest', 'shoulders'],
            status          => 'completed',
            durationMinutes => 55,
            perceivedEffort => 7,
        }),
    }
);
show($session_res);
check("Sessions create returns 201", $session_res->{status} == 201);

my $session_id;
if ($session_res->{status} == 201) {
    my $data = eval { $json->decode($session_res->{content}) };
    $session_id = $data->{id} if $data;
}

section("Sessions: GET /fitness/sessions (list, date range filter)");
my $session_list_res = $http->get(
    "$BASE_URL/fitness/sessions?from=2026-01-01&to=2026-12-31",
    { headers => auth_headers($token_a, 0) }
);
show($session_list_res);
check("Sessions list returns 200", $session_list_res->{status} == 200);
if ($session_list_res->{status} == 200 && $session_id) {
    my $data = eval { $json->decode($session_list_res->{content}) };
    my $found = ref($data) eq 'ARRAY' && grep { ($_->{id} // '') eq $session_id } @$data;
    check("Sessions list contains newly created session", $found ? 1 : 0);
}

if ($session_id) {
    section("Sessions: GET /fitness/sessions/:id (single, with nested exercises array)");
    my $session_get_res = $http->get("$BASE_URL/fitness/sessions/$session_id", { headers => auth_headers($token_a, 0) });
    show($session_get_res);
    check("Sessions GET/:id returns 200", $session_get_res->{status} == 200);
    if ($session_get_res->{status} == 200) {
        my $data = eval { $json->decode($session_get_res->{content}) };
        check("Sessions GET/:id includes an exercises array (empty is fine - no sub-resource endpoints yet)",
            $data && ref($data->{exercises}) eq 'ARRAY');
    }

    section("Sessions: PATCH /fitness/sessions/:id (edit status/duration/RPE)");
    my $session_patch_res = $http->request('PATCH', "$BASE_URL/fitness/sessions/$session_id", {
        headers => auth_headers($token_a, 1),
        content => $json->encode({ status => 'skipped', durationMinutes => 0, perceivedEffort => 0 }),
    });
    show($session_patch_res);
    check("Sessions PATCH returns 200", $session_patch_res->{status} == 200);
    if ($session_patch_res->{status} == 200) {
        my $data = eval { $json->decode($session_patch_res->{content}) };
        check("Sessions PATCH actually updated status", $data && $data->{status} eq 'skipped');
    }

    section("Sessions: Negative - no auth token");
    my $session_no_auth_res = $http->get("$BASE_URL/fitness/sessions");
    show($session_no_auth_res);
    check("Sessions list with no auth returns 401", $session_no_auth_res->{status} == 401);

    if ($token_b) {
        section("Sessions: Isolation - user B cannot access user A's session");
        my $session_b_res = $http->get("$BASE_URL/fitness/sessions/$session_id", { headers => auth_headers($token_b, 0) });
        show($session_b_res);
        check("Sessions user B GET/:id on user A's session returns 404", $session_b_res->{status} == 404);

        my $session_b_delete_res = $http->request('DELETE', "$BASE_URL/fitness/sessions/$session_id", { headers => auth_headers($token_b, 0) });
        show($session_b_delete_res);
        check("Sessions user B DELETE on user A's session returns 404", $session_b_delete_res->{status} == 404);
    }

    section("Sessions: DELETE /fitness/sessions/:id (as owner)");
    my $session_delete_res = $http->request('DELETE', "$BASE_URL/fitness/sessions/$session_id", { headers => auth_headers($token_a, 0) });
    show($session_delete_res);
    check("Sessions DELETE returns 204", $session_delete_res->{status} == 204);

    section("Sessions: GET /fitness/sessions/:id after delete (should 404)");
    my $session_after_delete_res = $http->get("$BASE_URL/fitness/sessions/$session_id", { headers => auth_headers($token_a, 0) });
    show($session_after_delete_res);
    check("Sessions GET/:id after delete returns 404", $session_after_delete_res->{status} == 404);
}

# ---------------------------------------------------------------
section("14. Exercise History: setup - create session + exercise + set");
# ---------------------------------------------------------------
my $hist_session_res = $http->post(
    "$BASE_URL/fitness/sessions",
    {
        headers => auth_headers($token_a, 1),
        content => $json->encode({
            date  => '2026-09-05T00:00:00.000Z',
            title => 'History Test Session',
        }),
    }
);
show($hist_session_res);
check("History setup - session create returns 201", $hist_session_res->{status} == 201);

my $hist_session_id;
if ($hist_session_res->{status} == 201) {
    my $data = eval { $json->decode($hist_session_res->{content}) };
    $hist_session_id = $data->{id} if $data;
}

my $hist_exercise_id;
if ($hist_session_id) {
    my $hist_ex_res = $http->post(
        "$BASE_URL/fitness/sessions/$hist_session_id/exercises",
        {
            headers => auth_headers($token_a, 1),
            content => $json->encode({ name => 'HistoryTestExercise', order => 0 }),
        }
    );
    show($hist_ex_res);
    check("History setup - exercise create returns 201", $hist_ex_res->{status} == 201);
    if ($hist_ex_res->{status} == 201) {
        my $data = eval { $json->decode($hist_ex_res->{content}) };
        $hist_exercise_id = $data->{id} if $data;
    }
}

if ($hist_exercise_id) {
    my $hist_set_res = $http->post(
        "$BASE_URL/fitness/sessions/$hist_session_id/exercises/$hist_exercise_id/sets",
        {
            headers => auth_headers($token_a, 1),
            content => $json->encode({ kind => 'working', weightKg => 100, reps => 5, rpe => 8, completed => JSON::PP::true }),
        }
    );
    show($hist_set_res);
    check("History setup - set create returns 201", $hist_set_res->{status} == 201);
}

section("Exercise History: GET /fitness/exercises/HistoryTestExercise/history");
my $hist_res = $http->get(
    "$BASE_URL/fitness/exercises/HistoryTestExercise/history",
    { headers => auth_headers($token_a, 0) }
);
show($hist_res);
check("Exercise history returns 200", $hist_res->{status} == 200);
if ($hist_res->{status} == 200) {
    my $data = eval { $json->decode($hist_res->{content}) };
    check("Exercise history response is a bare JSON array", ref($data) eq 'ARRAY');
    my ($entry) = grep { ($_->{weightKg} // 0) == 100 && ($_->{reps} // 0) == 5 } @$data;
    check("Exercise history contains the set just created", $entry ? 1 : 0);
}

section("Exercise History: negative - no auth token");
my $hist_no_auth_res = $http->get("$BASE_URL/fitness/exercises/HistoryTestExercise/history");
show($hist_no_auth_res);
check("Exercise history with no auth returns 401", $hist_no_auth_res->{status} == 401);

if ($token_b) {
    section("Exercise History: Isolation - user B sees no entries for user A's exercise name");
    my $hist_b_res = $http->get(
        "$BASE_URL/fitness/exercises/HistoryTestExercise/history",
        { headers => auth_headers($token_b, 0) }
    );
    show($hist_b_res);
    if ($hist_b_res->{status} == 200) {
        my $data = eval { $json->decode($hist_b_res->{content}) };
        check("Exercise history user B array does not contain user A's entry",
            ref($data) eq 'ARRAY' && scalar(@$data) == 0);
    }
}

# cleanup
if ($hist_session_id) {
    $http->request('DELETE', "$BASE_URL/fitness/sessions/$hist_session_id", { headers => auth_headers($token_a, 0) });
}


# ---------------------------------------------------------------
section("15. Fitness Summary: GET /fitness/summary");
# ---------------------------------------------------------------
my $fitness_summary_res = $http->get("$BASE_URL/fitness/summary", { headers => auth_headers($token_a, 0) });
show($fitness_summary_res);
check("Fitness summary returns 200", $fitness_summary_res->{status} == 200);
if ($fitness_summary_res->{status} == 200) {
    my $data = eval { $json->decode($fitness_summary_res->{content}) };
    check("Fitness summary includes last30Days object",
        $data && ref($data->{last30Days}) eq 'HASH');
    check("Fitness summary last30Days has sessionsCompleted/sessionsPlanned/adherencePercent/totalVolumeKg",
        $data && exists $data->{last30Days}{sessionsCompleted}
              && exists $data->{last30Days}{sessionsPlanned}
              && exists $data->{last30Days}{adherencePercent}
              && exists $data->{last30Days}{totalVolumeKg});
    check("Fitness summary includes estimatedOneRepMaxByExercise object",
        $data && ref($data->{estimatedOneRepMaxByExercise}) eq 'HASH');
}

section("Fitness Summary: negative - no auth token");
my $fitness_summary_no_auth_res = $http->get("$BASE_URL/fitness/summary");
show($fitness_summary_no_auth_res);
check("Fitness summary with no auth returns 401", $fitness_summary_no_auth_res->{status} == 401);




# ---------------------------------------------------------------
section("SUMMARY");
# ---------------------------------------------------------------
print "Passed: $pass_count\n";
print "Failed: $fail_count\n";
print $fail_count == 0 ? "\nALL TESTS PASSED\n" : "\nSOME TESTS FAILED - see above\n";

