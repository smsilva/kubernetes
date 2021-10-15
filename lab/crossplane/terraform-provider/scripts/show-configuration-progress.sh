#!/bin/bash

show_crossplane_pods() {
  kubectl get pods -n crossplane-system
}

show_custom_resources() {
  kubectl api-resources | grep -E "NAME|silvios.me"
}

echo "Crossplane PODs:             " && echo "" && (show_crossplane_pods                    ) 2>&1 | awk '{ print "  " $0 }' && echo "" && \
echo "Configuration Package:       " && echo "" && (kubectl get Configuration.pkg           ) 2>&1 | awk '{ print "  " $0 }' && echo "" && \
echo "Provider:                    " && echo "" && (kubectl get Provider                    ) 2>&1 | awk '{ print "  " $0 }' && echo "" && \
echo "Custom Resources:            " && echo "" && (show_custom_resources                   ) 2>&1 | awk '{ print "  " $0 }' && echo "" && \
echo "CompositeResourceDefinition: " && echo "" && (kubectl get CompositeResourceDefinition ) 2>&1 | awk '{ print "  " $0 }' && echo "" && \
echo "Compositions:                " && echo "" && (kubectl get Composition                 ) 2>&1 | awk '{ print "  " $0 }' && echo "" && \
echo "ProviderConfig:              " && echo "" && (kubectl get ProviderConfig              ) 2>&1 | awk '{ print "  " $0 }' && echo "" && \
echo ""
