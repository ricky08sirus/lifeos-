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
    my $path             = $args{path};
    my $create_payload   = $args{create_payload};
    my $invalid_payload  = $args{invalid_payload};
    my $patch_payload    = $args{patch_payload};
    my $patch_field      = $args{patch_field};
    my $patch_value      = $args{patch_value};
    my $list_query       = $args{list_query};
    my $soft_delete       = $args{soft_delete};

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

    if (defined $patch_payload) {
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

        if (defined $patch_payload) {
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
        }

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

    if (defined $patch_payload) {
        section("$name: PATCH /$path/$id after delete");
        my $after_delete_res = $http->request(
            'PATCH',
            "$BASE_URL/$path/$id",
            {
                headers => auth_headers($token_a, 1),
                content => $json->encode($patch_payload),
            }
        );
        show($after_delete_res);
        if ($soft_delete) {
            # Soft-delete resources keep the row (archivedAt set) - PATCH after
            # delete legitimately still succeeds with 200, not 404.
            check("$name PATCH after delete returns 200 (soft-delete)", $after_delete_res->{status} == 200);
            if ($after_delete_res->{status} == 200) {
                my $data = eval { $json->decode($after_delete_res->{content}) };
                check("$name archivedAt is actually set after delete", $data && $data->{archivedAt});
            }
        } else {
            check("$name PATCH after delete returns 404", $after_delete_res->{status} == 404);
        }
    }
}

# ---------------------------------------------------------------
# 1. Weights
# ---------------------------------------------------------------
test_resource(
    name            => 'Weights',
    path            => 'health/weights',
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
    path            => 'health/measurements',
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
    path            => 'health/sleep',
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
    path            => 'health/wellbeing',
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
    path            => 'health/vitals',
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
    path            => 'health/medications',
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
    path            => 'health/appointments',
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
# 16. Nutrition: Meals (full CRUD)
# ---------------------------------------------------------------
test_resource(
    name            => 'Meals',
    path            => 'nutrition/meals',
    create_payload  => { date => '2026-09-01T08:00:00.000Z', slot => 'breakfast', label => 'Oats + banana', calories => 350, protein => 12 },
    invalid_payload => { date => '2026-09-01T08:00:00.000Z', slot => 'breakfast' },  # missing label
    patch_payload   => { calories => 400 },
    patch_field     => 'calories',
    patch_value     => 400,
    list_query      => 'slot=breakfast',
);

# ---------------------------------------------------------------
# 17. Nutrition: Water (no PATCH endpoint)
# ---------------------------------------------------------------
test_resource(
    name            => 'Water',
    path            => 'nutrition/water',
    create_payload  => { date => '2026-09-01T08:00:00.000Z', amountMl => 500 },
    invalid_payload => { date => '2026-09-01T08:00:00.000Z' },  # missing amountMl
    patch_payload   => undef,
);

# ---------------------------------------------------------------
# 18. Nutrition: Foods (GET/POST only - custom block, no PATCH/DELETE)
# ---------------------------------------------------------------
section("Foods: POST /nutrition/foods with invalid body (expect 400)");
my $food_bad_res = $http->post("$BASE_URL/nutrition/foods", {
    headers => auth_headers($token_a, 1),
    content => $json->encode({ calories => 200 }),  # missing name
});
show($food_bad_res);
check("Foods POST missing name returns 400", $food_bad_res->{status} == 400);

section("Foods: POST /nutrition/foods (create)");
my $food_res = $http->post("$BASE_URL/nutrition/foods", {
    headers => auth_headers($token_a, 1),
    content => $json->encode({ name => 'Paneer Tikka', dietTags => ['lacto_vegetarian'], calories => 250, protein => 18 }),
});
show($food_res);
check("Foods create returns 201", $food_res->{status} == 201);

my $food_id;
if ($food_res->{status} == 201) {
    my $data = eval { $json->decode($food_res->{content}) };
    $food_id = $data->{id} if $data;
}

section("Foods: GET /nutrition/foods?q=Paneer (search)");
my $food_search_res = $http->get("$BASE_URL/nutrition/foods?q=Paneer", { headers => auth_headers($token_a, 0) });
show($food_search_res);
check("Foods search returns 200", $food_search_res->{status} == 200);
if ($food_search_res->{status} == 200 && $food_id) {
    my $data = eval { $json->decode($food_search_res->{content}) };
    my $found = ref($data) eq 'ARRAY' && grep { ($_->{id} // '') eq $food_id } @$data;
    check("Foods search finds newly created food", $found ? 1 : 0);
}

section("Foods: negative - no auth token");
my $food_no_auth_res = $http->get("$BASE_URL/nutrition/foods");
show($food_no_auth_res);
check("Foods GET with no auth returns 401", $food_no_auth_res->{status} == 401);

# ---------------------------------------------------------------
# 19. Nutrition: Summary (read-only)
# ---------------------------------------------------------------
section("19. GET /nutrition/summary");
my $nutrition_summary_res = $http->get("$BASE_URL/nutrition/summary?date=2026-09-01", { headers => auth_headers($token_a, 0) });
show($nutrition_summary_res);
check("Nutrition summary returns 200", $nutrition_summary_res->{status} == 200);
if ($nutrition_summary_res->{status} == 200) {
    my $data = eval { $json->decode($nutrition_summary_res->{content}) };
    check("Nutrition summary includes totals and targets objects",
        $data && ref($data->{totals}) eq 'HASH' && ref($data->{targets}) eq 'HASH');
}

section("Nutrition summary: negative - no auth token");
my $nutrition_summary_no_auth_res = $http->get("$BASE_URL/nutrition/summary");
show($nutrition_summary_no_auth_res);
check("Nutrition summary with no auth returns 401", $nutrition_summary_no_auth_res->{status} == 401);


# ---------------------------------------------------------------
# 20. Habits: definitions (full CRUD, archive-as-delete)
# ---------------------------------------------------------------
# NOTE: Habits uses soft-delete (sets archivedAt, keeps the row) so habit logs
# don't get orphaned. The generic test_resource() "PATCH after delete returns 404"
# check will always FAIL here by design - this is expected, not a bug.
test_resource(
    name            => 'Habits',
    path            => 'habits',
    create_payload  => { name => 'Meditate', cadence => 'daily', metricType => 'boolean' },
    invalid_payload => { cadence => 'daily' },
    patch_payload   => { name => 'Meditate (updated)' },
    patch_field     => 'name',
    patch_value     => 'Meditate (updated)',
    soft_delete     => 1,
);

# ---------------------------------------------------------------
# 21. Habits: Logs (date-keyed, not id-keyed - custom block)
# ---------------------------------------------------------------
section("21. Habits Logs: create a habit to log against");
my $habit_res = $http->post("$BASE_URL/habits", {
    headers => auth_headers($token_a, 1),
    content => $json->encode({ name => 'Drink water', cadence => 'daily', metricType => 'boolean' }),
});
show($habit_res);
my $habit_id;
if ($habit_res->{status} == 201) {
    my $data = eval { $json->decode($habit_res->{content}) };
    $habit_id = $data->{id} if $data;
}
check("Habit created for log testing", $habit_id ? 1 : 0);

if ($habit_id) {
    section("Habits Logs: PUT /habits/:id/logs/:date (set to done)");
    my $log_put_res = $http->request('PUT', "$BASE_URL/habits/$habit_id/logs/2026-09-01", {
        headers => auth_headers($token_a, 1),
        content => $json->encode({ status => 'done' }),
    });
    show($log_put_res);
    check("Habits Logs PUT returns 200", $log_put_res->{status} == 200);

    section("Habits Logs: PUT again on same date (overwrite to skipped)");
    my $log_overwrite_res = $http->request('PUT', "$BASE_URL/habits/$habit_id/logs/2026-09-01", {
        headers => auth_headers($token_a, 1),
        content => $json->encode({ status => 'skipped' }),
    });
    show($log_overwrite_res);
    check("Habits Logs PUT overwrite returns 200", $log_overwrite_res->{status} == 200);
    if ($log_overwrite_res->{status} == 200) {
        my $data = eval { $json->decode($log_overwrite_res->{content}) };
        check("Habits Logs overwrite actually changed status to skipped", $data && $data->{status} eq 'skipped');
    }

    section("Habits Logs: GET /habits/:id/logs (list)");
    my $log_list_res = $http->get("$BASE_URL/habits/$habit_id/logs", { headers => auth_headers($token_a, 0) });
    show($log_list_res);
    check("Habits Logs list returns 200", $log_list_res->{status} == 200);
    if ($log_list_res->{status} == 200) {
        my $data = eval { $json->decode($log_list_res->{content}) };
        check("Habits Logs list has exactly one entry (overwrite, not duplicate)",
            ref($data) eq 'ARRAY' && scalar(@$data) == 1);
    }

    section("Habits Logs: negative - no auth token");
    my $log_no_auth_res = $http->get("$BASE_URL/habits/$habit_id/logs");
    show($log_no_auth_res);
    check("Habits Logs GET with no auth returns 401", $log_no_auth_res->{status} == 401);

    if ($token_b) {
        section("Habits Logs: isolation - user B cannot log against user A's habit");
        my $log_b_res = $http->request('PUT', "$BASE_URL/habits/$habit_id/logs/2026-09-02", {
            headers => auth_headers($token_b, 1),
            content => $json->encode({ status => 'done' }),
        });
        show($log_b_res);
        check("Habits Logs user B PUT on user A's habit returns 404", $log_b_res->{status} == 404);
    }

    section("Habits Logs: DELETE /habits/:id/logs/:date (clear back to unlogged)");
    my $log_delete_res = $http->request('DELETE', "$BASE_URL/habits/$habit_id/logs/2026-09-01", { headers => auth_headers($token_a, 0) });
    show($log_delete_res);
    check("Habits Logs DELETE returns 204", $log_delete_res->{status} == 204);

    section("Habits Logs: GET after delete (list should be empty)");
    my $log_after_delete_res = $http->get("$BASE_URL/habits/$habit_id/logs", { headers => auth_headers($token_a, 0) });
    show($log_after_delete_res);
    if ($log_after_delete_res->{status} == 200) {
        my $data = eval { $json->decode($log_after_delete_res->{content}) };
        check("Habits Logs list is empty after delete", ref($data) eq 'ARRAY' && scalar(@$data) == 0);
    }
}

# ---------------------------------------------------------------
# 22. Habits: Summary (read-only)
# ---------------------------------------------------------------
section("22. GET /habits/summary");
my $habits_summary_res = $http->get("$BASE_URL/habits/summary", { headers => auth_headers($token_a, 0) });
show($habits_summary_res);
check("Habits summary returns 200", $habits_summary_res->{status} == 200);
if ($habits_summary_res->{status} == 200) {
    my $data = eval { $json->decode($habits_summary_res->{content}) };
    check("Habits summary includes a habits array", $data && ref($data->{habits}) eq 'ARRAY');
}

section("Habits summary: negative - no auth token");
my $habits_summary_no_auth_res = $http->get("$BASE_URL/habits/summary");
show($habits_summary_no_auth_res);
check("Habits summary with no auth returns 401", $habits_summary_no_auth_res->{status} == 401);


# ---------------------------------------------------------------
# 23. Finance: Income (singleton resource - GET/PATCH only, no id, no list)
# ---------------------------------------------------------------
section("23. Finance Income: PATCH /finance/income with invalid body (expect 400)");
my $income_bad_res = $http->request('PATCH', "$BASE_URL/finance/income", {
    headers => auth_headers($token_a, 1),
    content => $json->encode({ label => 'Salary' }),  # missing monthlyNetPaise
});
show($income_bad_res);
check("Finance Income PATCH missing monthlyNetPaise returns 400", $income_bad_res->{status} == 400);

section("Finance Income: PATCH /finance/income (create via upsert)");
my $income_res = $http->request('PATCH', "$BASE_URL/finance/income", {
    headers => auth_headers($token_a, 1),
    content => $json->encode({ monthlyNetPaise => 8000000, label => 'Salary' }),
});
show($income_res);
check("Finance Income PATCH returns 200", $income_res->{status} == 200);
if ($income_res->{status} == 200) {
    my $data = eval { $json->decode($income_res->{content}) };
    check("Finance Income monthlyNetPaise stored correctly", $data && $data->{monthlyNetPaise} == 8000000);
}

section("Finance Income: GET /finance/income");
my $income_get_res = $http->get("$BASE_URL/finance/income", { headers => auth_headers($token_a, 0) });
show($income_get_res);
check("Finance Income GET returns 200", $income_get_res->{status} == 200);

section("Finance Income: PATCH again (upsert overwrite)");
my $income_update_res = $http->request('PATCH', "$BASE_URL/finance/income", {
    headers => auth_headers($token_a, 1),
    content => $json->encode({ monthlyNetPaise => 8500000 }),
});
show($income_update_res);
check("Finance Income PATCH overwrite returns 200", $income_update_res->{status} == 200);
if ($income_update_res->{status} == 200) {
    my $data = eval { $json->decode($income_update_res->{content}) };
    check("Finance Income overwrite actually updated monthlyNetPaise", $data && $data->{monthlyNetPaise} == 8500000);
}

section("Finance Income: negative - no auth token");
my $income_no_auth_res = $http->get("$BASE_URL/finance/income");
show($income_no_auth_res);
check("Finance Income GET with no auth returns 401", $income_no_auth_res->{status} == 401);

# ---------------------------------------------------------------
# 24. Finance: Accounts (full CRUD)
# ---------------------------------------------------------------
test_resource(
    name            => 'Finance Accounts',
    path            => 'finance/accounts',
    create_payload  => { name => 'HDFC Savings', kind => 'savings', institution => 'HDFC Bank', balancePaise => 5000000, isPrimary => JSON::PP::true },
    invalid_payload => { institution => 'HDFC Bank' },  # missing name and kind
    patch_payload   => { balancePaise => 4500000 },
    patch_field     => 'balancePaise',
    patch_value     => 4500000,
);

# ---------------------------------------------------------------
# 25. Finance: Categories (full CRUD)
# ---------------------------------------------------------------
test_resource(
    name            => 'Finance Categories',
    path            => 'finance/categories',
    create_payload  => { name => 'Groceries', group => 'Food', isNeed => JSON::PP::true, budgetPaise => 1500000 },
    invalid_payload => { isNeed => JSON::PP::true },  # missing name and group
    patch_payload   => { budgetPaise => 1800000 },
    patch_field     => 'budgetPaise',
    patch_value     => 1800000,
);

# ---------------------------------------------------------------
# 26. Finance: Transactions (needs an account + category to reference - custom setup)
# ---------------------------------------------------------------
section("26. Finance Transactions: setup - create account + category to reference");
my $txn_account_res = $http->post("$BASE_URL/finance/accounts", {
    headers => auth_headers($token_a, 1),
    content => $json->encode({ name => 'ICICI Checking', kind => 'savings' }),
});
show($txn_account_res);
my $txn_account_id;
if ($txn_account_res->{status} == 201) {
    my $data = eval { $json->decode($txn_account_res->{content}) };
    $txn_account_id = $data->{id} if $data;
}
check("Finance Transactions setup - account created", $txn_account_id ? 1 : 0);

my $txn_category_res = $http->post("$BASE_URL/finance/categories", {
    headers => auth_headers($token_a, 1),
    content => $json->encode({ name => 'Dining Out', group => 'Food' }),
});
show($txn_category_res);
my $txn_category_id;
if ($txn_category_res->{status} == 201) {
    my $data = eval { $json->decode($txn_category_res->{content}) };
    $txn_category_id = $data->{id} if $data;
}
check("Finance Transactions setup - category created", $txn_category_id ? 1 : 0);

if ($txn_account_id) {
    section("Finance Transactions: POST /finance/transactions with invalid body (expect 400)");
    my $txn_bad_res = $http->post("$BASE_URL/finance/transactions", {
        headers => auth_headers($token_a, 1),
        content => $json->encode({ merchant => 'Zomato' }),  # missing amountPaise, accountId, date
    });
    show($txn_bad_res);
    check("Finance Transactions POST missing required fields returns 400", $txn_bad_res->{status} == 400);

    section("Finance Transactions: POST /finance/transactions with someone else's accountId (expect 400)");
    my $fake_account_res = $http->post("$BASE_URL/finance/transactions", {
        headers => auth_headers($token_a, 1),
        content => $json->encode({
            merchant => 'Zomato', amountPaise => 45000, accountId => 'nonexistent-account-id',
            date => '2026-09-01T00:00:00.000Z',
        }),
    });
    show($fake_account_res);
    check("Finance Transactions POST with invalid accountId returns 400", $fake_account_res->{status} == 400);

    section("Finance Transactions: POST /finance/transactions (valid)");
    my $txn_res = $http->post("$BASE_URL/finance/transactions", {
        headers => auth_headers($token_a, 1),
        content => $json->encode({
            merchant   => 'Zomato',
            amountPaise => 45000,
            accountId   => $txn_account_id,
            categoryId  => $txn_category_id,
            date        => '2026-09-01T00:00:00.000Z',
        }),
    });
    show($txn_res);
    check("Finance Transactions create returns 201", $txn_res->{status} == 201);

    my $txn_id;
    if ($txn_res->{status} == 201) {
        my $data = eval { $json->decode($txn_res->{content}) };
        $txn_id = $data->{id} if $data;
    }

    section("Finance Transactions: GET /finance/transactions (filter by accountId)");
    my $txn_list_res = $http->get("$BASE_URL/finance/transactions?accountId=$txn_account_id", { headers => auth_headers($token_a, 0) });
    show($txn_list_res);
    check("Finance Transactions filtered list returns 200", $txn_list_res->{status} == 200);
    if ($txn_list_res->{status} == 200 && $txn_id) {
        my $data = eval { $json->decode($txn_list_res->{content}) };
        my $found = ref($data) eq 'ARRAY' && grep { ($_->{id} // '') eq $txn_id } @$data;
        check("Finance Transactions filtered list contains the new transaction", $found ? 1 : 0);
    }

    if ($txn_id) {
        section("Finance Transactions: PATCH /finance/transactions/:id (re-categorize)");
        my $txn_patch_res = $http->request('PATCH', "$BASE_URL/finance/transactions/$txn_id", {
            headers => auth_headers($token_a, 1),
            content => $json->encode({ merchant => 'Swiggy' }),
        });
        show($txn_patch_res);
        check("Finance Transactions PATCH returns 200", $txn_patch_res->{status} == 200);
        if ($txn_patch_res->{status} == 200) {
            my $data = eval { $json->decode($txn_patch_res->{content}) };
            check("Finance Transactions PATCH actually updated merchant", $data && $data->{merchant} eq 'Swiggy');
        }

        section("Finance Transactions: negative - no auth token");
        my $txn_no_auth_res = $http->get("$BASE_URL/finance/transactions");
        show($txn_no_auth_res);
        check("Finance Transactions GET with no auth returns 401", $txn_no_auth_res->{status} == 401);

        if ($token_b) {
            section("Finance Transactions: Isolation - user B cannot access user A's transaction");
            my $txn_b_patch_res = $http->request('PATCH', "$BASE_URL/finance/transactions/$txn_id", {
                headers => auth_headers($token_b, 1),
                content => $json->encode({ merchant => 'Hacked' }),
            });
            show($txn_b_patch_res);
            check("Finance Transactions user B PATCH on user A's transaction returns 404", $txn_b_patch_res->{status} == 404);
        }

        section("Finance Transactions: DELETE /finance/transactions/:id");
        my $txn_delete_res = $http->request('DELETE', "$BASE_URL/finance/transactions/$txn_id", { headers => auth_headers($token_a, 0) });
        show($txn_delete_res);
        check("Finance Transactions DELETE returns 204", $txn_delete_res->{status} == 204);
    }
}

# cleanup
if ($txn_account_id) {
    $http->request('DELETE', "$BASE_URL/finance/accounts/$txn_account_id", { headers => auth_headers($token_a, 0) });
}
if ($txn_category_id) {
    $http->request('DELETE', "$BASE_URL/finance/categories/$txn_category_id", { headers => auth_headers($token_a, 0) });
}

# ---------------------------------------------------------------
# 27. Finance: Debts (full CRUD)
# ---------------------------------------------------------------
test_resource(
    name            => 'Finance Debts',
    path            => 'finance/debts',
    create_payload  => {
        name => 'iPhone EMI', kind => 'gadget_emi', lender => 'Bajaj Finance',
        principalPaise => 8000000, annualRatePct => 14.5, termMonths => 12,
        startedOn => '2026-01-01T00:00:00.000Z', emiPaise => 700000,
        purchasePricePaise => 9000000, downPaymentPaise => 1000000,
    },
    invalid_payload => { name => 'iPhone EMI' },  # missing most required fields
    patch_payload   => { paidMonths => 3 },
    patch_field     => 'paidMonths',
    patch_value     => 3,
);

# ---------------------------------------------------------------
# 28. Finance: Bills (full CRUD)
# ---------------------------------------------------------------
test_resource(
    name            => 'Finance Bills',
    path            => 'finance/bills',
    create_payload  => { name => 'Electricity', amountPaise => 250000, dueDay => 5, recurrence => 'monthly', isVariable => JSON::PP::true },
    invalid_payload => { name => 'Electricity' },  # missing amountPaise, dueDay, recurrence
    patch_payload   => { amountPaise => 280000 },
    patch_field     => 'amountPaise',
    patch_value     => 280000,
);

# ---------------------------------------------------------------
# 29. Finance: Subscriptions (GET/POST only - custom block, no PATCH/DELETE per spec)
# ---------------------------------------------------------------
section("29. Finance Subscriptions: POST /finance/subscriptions with invalid body (expect 400)");
my $sub_bad_res = $http->post("$BASE_URL/finance/subscriptions", {
    headers => auth_headers($token_a, 1),
    content => $json->encode({ name => 'Netflix' }),  # missing amountPaise, recurrence, dueDay
});
show($sub_bad_res);
check("Finance Subscriptions POST missing required fields returns 400", $sub_bad_res->{status} == 400);

section("Finance Subscriptions: POST /finance/subscriptions (create)");
my $sub_res = $http->post("$BASE_URL/finance/subscriptions", {
    headers => auth_headers($token_a, 1),
    content => $json->encode({ name => 'Netflix', amountPaise => 64900, recurrence => 'monthly', dueDay => 10, lastUsedDaysAgo => 45 }),
});
show($sub_res);
check("Finance Subscriptions create returns 201", $sub_res->{status} == 201);

my $sub_id;
if ($sub_res->{status} == 201) {
    my $data = eval { $json->decode($sub_res->{content}) };
    $sub_id = $data->{id} if $data;
}

section("Finance Subscriptions: GET /finance/subscriptions (list)");
my $sub_list_res = $http->get("$BASE_URL/finance/subscriptions", { headers => auth_headers($token_a, 0) });
show($sub_list_res);
check("Finance Subscriptions list returns 200", $sub_list_res->{status} == 200);
if ($sub_list_res->{status} == 200 && $sub_id) {
    my $data = eval { $json->decode($sub_list_res->{content}) };
    my $found = ref($data) eq 'ARRAY' && grep { ($_->{id} // '') eq $sub_id } @$data;
    check("Finance Subscriptions list contains newly created subscription", $found ? 1 : 0);
}

section("Finance Subscriptions: negative - no auth token");
my $sub_no_auth_res = $http->get("$BASE_URL/finance/subscriptions");
show($sub_no_auth_res);
check("Finance Subscriptions GET with no auth returns 401", $sub_no_auth_res->{status} == 401);



# ---------------------------------------------------------------
# 30. Finance: Investments (full CRUD)
# ---------------------------------------------------------------
test_resource(
    name            => 'Finance Investments',
    path            => 'finance/investments',
    create_payload  => { name => 'Nifty 50 Index', kind => 'mutual_fund', units => 100.5, avgCostPaise => 2500, currentNavPaise => 2800, sipPaise => 500000, sipDay => 5, since => '2024-01-01T00:00:00.000Z' },
    invalid_payload => { name => 'Nifty 50 Index', kind => 'mutual_fund' },  # missing units, avgCostPaise, currentNavPaise, since
    patch_payload   => { currentNavPaise => 2950 },
    patch_field     => 'currentNavPaise',
    patch_value     => 2950,
);


# ---------------------------------------------------------------
# 31. Finance: Assets (full CRUD)
# ---------------------------------------------------------------
test_resource(
    name            => 'Finance Assets',
    path            => 'finance/assets',
    create_payload  => { name => 'Maruti Baleno', kind => 'vehicle', valuePaise => 52000000, acquiredOn => '2023-06-01T00:00:00.000Z', depreciating => JSON::PP::true },
    invalid_payload => { name => 'Maruti Baleno' },  # missing kind, valuePaise, acquiredOn
    patch_payload   => { valuePaise => 48000000 },
    patch_field     => 'valuePaise',
    patch_value     => 48000000,
);


# ---------------------------------------------------------------
# 32. Finance: Goals (full CRUD)
# ---------------------------------------------------------------
test_resource(
    name            => 'Finance Goals',
    path            => 'finance/goals',
    create_payload  => { name => 'Emergency fund', targetPaise => 60000000, savedPaise => 15000000, targetDate => '2027-01-01T00:00:00.000Z', priority => 1 },
    invalid_payload => { savedPaise => 15000000 },  # missing name and targetPaise
    patch_payload   => { savedPaise => 20000000 },
    patch_field     => 'savedPaise',
    patch_value     => 20000000,
);



# ---------------------------------------------------------------
# 33. Finance: Insurance (full CRUD)
# ---------------------------------------------------------------
test_resource(
    name            => 'Finance Insurance',
    path            => 'finance/insurance',
    create_payload  => { kind => 'term_life', provider => 'HDFC Life', coverPaise => 1000000000, premiumPaise => 2574000, renewalOn => '2027-03-01T00:00:00.000Z', frequency => 'annual' },
    invalid_payload => { kind => 'term_life', provider => 'HDFC Life' },  # missing coverPaise, premiumPaise, renewalOn, frequency
    patch_payload   => { premiumPaise => 2700000 },
    patch_field     => 'premiumPaise',
    patch_value     => 2700000,
);



# ---------------------------------------------------------------
# 34. Finance: Net Worth (GET history + POST snapshot)
# ---------------------------------------------------------------
section("34. Finance Net Worth: GET /finance/net-worth (empty or existing history)");
my $nw_get_res = $http->get("$BASE_URL/finance/net-worth", { headers => auth_headers($token_a, 0) });
show($nw_get_res);
check("Finance Net Worth GET returns 200", $nw_get_res->{status} == 200);
if ($nw_get_res->{status} == 200) {
    my $data = eval { $json->decode($nw_get_res->{content}) };
    check("Finance Net Worth GET response is a bare JSON array", ref($data) eq 'ARRAY');
}

section("Finance Net Worth: POST /finance/net-worth/snapshot (create a snapshot)");
my $nw_snap_res = $http->post("$BASE_URL/finance/net-worth/snapshot", {
    headers => auth_headers($token_a, 1),
    content => '{}',
});
show($nw_snap_res);
check("Finance Net Worth snapshot returns 201", $nw_snap_res->{status} == 201);
if ($nw_snap_res->{status} == 201) {
    my $data = eval { $json->decode($nw_snap_res->{content}) };
    check("Finance Net Worth snapshot includes netPaise", $data && exists $data->{netPaise});
}

section("Finance Net Worth: GET again (should now include the new snapshot)");
my $nw_get2_res = $http->get("$BASE_URL/finance/net-worth", { headers => auth_headers($token_a, 0) });
show($nw_get2_res);
check("Finance Net Worth GET after snapshot returns 200", $nw_get2_res->{status} == 200);
if ($nw_get2_res->{status} == 200) {
    my $data = eval { $json->decode($nw_get2_res->{content}) };
    check("Finance Net Worth history now has at least one entry",
        ref($data) eq 'ARRAY' && scalar(@$data) >= 1);
}

section("Finance Net Worth: negative - no auth token");
my $nw_no_auth_res = $http->get("$BASE_URL/finance/net-worth");
show($nw_no_auth_res);
check("Finance Net Worth GET with no auth returns 401", $nw_no_auth_res->{status} == 401);



# ---------------------------------------------------------------
# 35. Finance: Budgets Summary (read-only)
# ---------------------------------------------------------------
section("35. GET /finance/budgets/summary");
my $budget_summary_res = $http->get("$BASE_URL/finance/budgets/summary", { headers => auth_headers($token_a, 0) });
show($budget_summary_res);
check("Finance Budgets Summary returns 200", $budget_summary_res->{status} == 200);
if ($budget_summary_res->{status} == 200) {
    my $data = eval { $json->decode($budget_summary_res->{content}) };
    check("Finance Budgets Summary includes categories array",
        $data && ref($data->{categories}) eq 'ARRAY');
}

section("Finance Budgets Summary: negative - no auth token");
my $budget_summary_no_auth_res = $http->get("$BASE_URL/finance/budgets/summary");
show($budget_summary_no_auth_res);
check("Finance Budgets Summary with no auth returns 401", $budget_summary_no_auth_res->{status} == 401);



# ---------------------------------------------------------------
# 36. Finance: Upcoming Dues (read-only)
# ---------------------------------------------------------------
section("36. GET /finance/upcoming-dues");
my $dues_res = $http->get("$BASE_URL/finance/upcoming-dues?days=14", { headers => auth_headers($token_a, 0) });
show($dues_res);
check("Finance Upcoming Dues returns 200", $dues_res->{status} == 200);
if ($dues_res->{status} == 200) {
    my $data = eval { $json->decode($dues_res->{content}) };
    check("Finance Upcoming Dues includes items array and totalPaise",
        $data && ref($data->{items}) eq 'ARRAY' && exists $data->{totalPaise});
}

section("Finance Upcoming Dues: negative - no auth token");
my $dues_no_auth_res = $http->get("$BASE_URL/finance/upcoming-dues");
show($dues_no_auth_res);
check("Finance Upcoming Dues with no auth returns 401", $dues_no_auth_res->{status} == 401);



# ---------------------------------------------------------------
# 37. Finance: Simulate (debt payoff simulation)
# ---------------------------------------------------------------
section("37. Finance Simulate: setup - create a debt to simulate against");
my $sim_debt_res = $http->post("$BASE_URL/finance/debts", {
    headers => auth_headers($token_a, 1),
    content => $json->encode({
        name => 'Simulation test loan', kind => 'personal_loan', lender => 'Test Bank',
        principalPaise => 30000000, annualRatePct => 12, termMonths => 24,
        startedOn => '2026-01-01T00:00:00.000Z', emiPaise => 1400000, paidMonths => 2,
    }),
});
show($sim_debt_res);
my $sim_debt_id;
if ($sim_debt_res->{status} == 201) {
    my $data = eval { $json->decode($sim_debt_res->{content}) };
    $sim_debt_id = $data->{id} if $data;
}
check("Simulate setup - debt created", $sim_debt_id ? 1 : 0);

section("Finance Simulate: POST /finance/simulate (snowball)");
my $sim_res = $http->post("$BASE_URL/finance/simulate", {
    headers => auth_headers($token_a, 1),
    content => $json->encode({ strategy => 'snowball', extraMonthlyPaise => 500000 }),
});
show($sim_res);
check("Finance Simulate returns 200", $sim_res->{status} == 200);
if ($sim_res->{status} == 200) {
    my $data = eval { $json->decode($sim_res->{content}) };
    check("Finance Simulate response includes months and totalInterestPaise",
        $data && exists $data->{months} && exists $data->{totalInterestPaise});
}

section("Finance Simulate: negative - no auth token");
my $sim_no_auth_res = $http->post("$BASE_URL/finance/simulate", {
    headers => { 'Content-Type' => 'application/json' },
    content => $json->encode({ strategy => 'snowball' }),
});
show($sim_no_auth_res);
check("Finance Simulate with no auth returns 401", $sim_no_auth_res->{status} == 401);

# cleanup
if ($sim_debt_id) {
    $http->request('DELETE', "$BASE_URL/finance/debts/$sim_debt_id", { headers => auth_headers($token_a, 0) });
}





# ---------------------------------------------------------------
section("SUMMARY");
# ---------------------------------------------------------------
print "Passed: $pass_count\n";
print "Failed: $fail_count\n";
print $fail_count == 0 ? "\nALL TESTS PASSED\n" : "\nSOME TESTS FAILED - see above\n";

