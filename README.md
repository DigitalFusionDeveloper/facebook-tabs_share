TODO
====

The contact forms still depend on styles and images stored in
*public/brands/whatever*. These need to be moved under assets and
public cleaned out.

Brands
======

All brands are configured in ./db/brands.yml - for instance

```yaml

---

brands:

  - title: O'Hara's
    organization: Paulaner
    rfi_fields: email, first_name, last_name, postal_code, mobile_phone, location

  - title: Paulaner
    organization: Paulaner
    rfi_fields: email, first_name, last_name, postal_code, mobile_phone, location


```

this data is the backing store for the model ./app/models/brands.rb

inside the app the brand's "slug" is used for all routing, lookups, etc.  the
slug can be set in the yaml file but will also automatically be drived from
the title, which is used for display purposes.

note setting the rfi_fields - this is non-DRY but, for now, required to make a
brand's rfi_fields appear in the global rfi report.  here is an example of
adding "Colorado Christian University"

```yaml

  -
    title: Colorado Christian University
    slug: ccu
    organization: ccu
    rfi_fields: email, first_name, last_name, term, street_address_1, street_address_2, city, state, zip, phone

```

Form Controller
===============

./app/controllers/forms_controller.rb serves rfi and locator forms.  the api
is an html one.
