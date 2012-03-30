/**
 * Copyright (C) 2012 Orbeon, Inc.
 *
 * This program is free software; you can redistribute it and/or modify it under the terms of the
 * GNU Lesser General Public License as published by the Free Software Foundation; either version
 * 2.1 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
 * without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU Lesser General Public License for more details.
 *
 * The full text of the license is available at http://www.gnu.org/copyleft/lesser.html
 */
package org.orbeon.oxf.xforms.control

import controls._
import org.orbeon.oxf.xforms.event.events.{DOMFocusOutEvent,DOMFocusInEvent}
import org.orbeon.oxf.xforms.control.Controls.AncestorIterator
import org.orbeon.oxf.xforms.XFormsContainingDocument
import org.orbeon.oxf.xforms.event.events.XFormsUIEvent
import collection.JavaConverters._

import java.util.{ArrayList ⇒ JArrayList, LinkedHashMap ⇒ JLinkedHashMap}
import org.orbeon.oxf.xforms.event._
import org.orbeon.oxf.xforms.event.XFormsEvents.{DOM_FOCUS_OUT, DOM_FOCUS_IN}

// Handle control focus
object Focus {

    // Focus on the given control and dispatch appropriate focus events
    def focusWithEvents(control: XFormsControl): Boolean = {

        // Continue only if control is focusable
        if (! isFocusable(control))
            return false

        val doc = control.containingDocument

        // Read previous control
        val previousOption = Option(doc.getControls.getFocusedControl)

        // Focus has not changed so don't do anything
        if (previousOption exists (_ eq control))
            return true

        // Remember first that the new control has focus
        doc.getControls.setFocusedControl(control)

        // Ancestor-or-self chains from root to leaf
        val previousChain = previousOption.toList flatMap (containersAndSelf(_).reverse)
        val currentChain = containersAndSelf(control).reverse

        // Number of common ancestor containers, if any
        val commonPrefix = previousChain zip currentChain prefixLength
            { case (previous, current) ⇒ previous eq current }

        // Focus out of the previous control and grouping controls we are leaving
        // Events are dispatched from leaf to root
        (previousChain drop commonPrefix reverse) foreach (focusOut(_))

        // Focus into the grouping controls we are entering and the current control
        // Events are dispatched from root to leaf
        currentChain drop commonPrefix foreach (focusIn(_))

        true
    }

    // Update focus based on a previously focused control
    def updateFocusWithEvents(focusedBefore: XFormsControl, repeat: Option[XFormsRepeatControl] = None) = repeat match {
        case Some(repeat) ⇒
            // Update the focus based on a previously focused control for which focus out events up to a repeat have
            // already been dispatched when a repeat iteration has been removed

            val doc = focusedBefore.containingDocument

            // Do as if focus hadn't been removed yet, as updateFocus expects it
            doc.getControls.setFocusedControl(focusedBefore)

            // Called if the focus is fully removed
            // Focus out events have been dispatched up to the iteration already, so just dispatch from the repeat to the root
            def removeFocus() =
                containersAndSelf(repeat) foreach (focusOut(_))

            // Called if the focus is changing to a new control
            // This will dispatch focus events from the new repeat iteration to the control
            def focus(control: XFormsControl) =
                setFocusPartially(control, Some(repeat))

            updateFocus(focusedBefore, removeFocus _, focus)
        case None ⇒
            updateFocus(focusedBefore, () ⇒ removeFocus(focusedBefore.containingDocument), focusWithEvents(_))
    }

    // Update focus based on a previously focused control
    private def updateFocus(focusedBefore: XFormsControl, onRemoveFocus: () ⇒ Any, onFocus: XFormsControl ⇒ Any) =
        if (focusedBefore ne null) {
            // There was a control with focus before

            // If there was a focused control and nobody has overwritten it with `setFocusedControl()` (NOTE:
            // destruction events can be dispatched upon updating bindings, and in theory change the focused control!),
            // make sure that the control is still able to hold focus. It may not, for example:
            //
            // - it may have become non-relevant or read-only
            // - it may have been in an iteration that has been removed
            //
            // If it's not able to hold focus, remove focus and dispatch focus events

            val doc = focusedBefore.containingDocument
            if (focusedBefore eq doc.getControls.getFocusedControl) {
                // Nobody has changed the focus with `setFocusedControl()`, which means nobody has dispatched
                // xforms-focus (or xforms-focus didn't actually change the focus). We need to validate that the control
                // with focus now is still focusable and is still following repeat indexes. If not, we must adjust the
                // focus accordingly.

                // Obtain a new reference to the control via the index, following repeats
                val newReferenceWithRepeats = XFormsRepeatControl.findControlFollowIndexes(focusedBefore)

                newReferenceWithRepeats match {
                    case None ⇒
                        // Cannot find a reference to the control anymore
                        // Control might be a ghost that has been removed from the tree (iteration removed)
                        onRemoveFocus()

                    case Some(newReference) if ! isFocusable(newReference) ⇒
                        // New reference exists, but is not focusable
                        onRemoveFocus()

                    case Some(newReference) if newReference ne focusedBefore ⇒
                        // Control exists and is focusable, and is not the same as the original control

                        // This covers the case where repeat indexes have been updated
                        // Here we move the focus to the new control
                        onFocus(newReference)

                    case _ ⇒
                        // Control exists, is focusable, and is the same as before, so we do nothing!
                }
            } else {
                // The focus is different or has been removed
                //
                // - if different, the change must have been done via xforms-focus
                // - if removed, the change might have been done in XFormsRepeatControl upon removing an iteration
                //
                // Either way events must have already been dispatched, so here we do nothing.
            }
        } else {
            // There was no focus before. If there is focus now, the change must have been done via xforms-focus, which
            // means that events have already been dispatched. If there is no focus now, nothing has changed. So here we
            // do nothing.
        }

    // Whether focus is currently within the given container
    def isFocusWithinContainer(container: XFormsContainerControl) =
        Option(container.containingDocument.getControls.getFocusedControl) match {
            case Some(control) if new AncestorIterator(control.parent) exists (_ eq container) ⇒ true
            case _ ⇒ false
        }

    private def isNotBoundary(control: XFormsControl, boundary: Option[XFormsContainerControl]) =
        boundary.isEmpty || (control ne boundary.get)
    
    // Partially remove the focus until the given boundary if any
    // The boundary is used by XFormsRepeatControl when an iteration is removed if the focus is within that iteration
    def removeFocusPartially(doc: XFormsContainingDocument, boundary: Option[XFormsContainerControl]) {

        // Dispatch DOMFocusOut events to the given control and to its container ancestors
        def dispatchFocusOuts(control: XFormsControl) =
            (containersAndSelf(control) takeWhile (isNotBoundary(_, boundary))) foreach (focusOut(_))

        // Dispatch focus out events if needed
        Option(doc.getControls.getFocusedControl) foreach { focused ⇒
            doc.getControls.clearFocusedControl()
            dispatchFocusOuts(focused)
        }
    }

    // Partially set the focus to the control, dispatching events from the given boundary if any
    def setFocusPartially(control: XFormsControl, boundary: Option[XFormsContainerControl]) {
        val doc = control.containingDocument

        // Remember first that the new control has focus
        doc.getControls.setFocusedControl(control)

        // Dispatch DOMFocusOut events to the given control and to its container ancestors
        def dispatchFocusIns(control: XFormsControl) =
            (containersAndSelf(control) takeWhile (isNotBoundary(_, boundary)) reverse) foreach (focusIn(_))

        // Dispatch focus in events
        dispatchFocusIns(control)
    }

    // Remove the focus entirely and dispatch the appropriate events
    def removeFocus(doc: XFormsContainingDocument) =
        removeFocusPartially(doc, boundary = None)

    // Find boundaries for event dispatch
    // Put here temporarily as this deals with focus events, but must be moved to some better place when possible
    def findBoundaries(targetObject: XFormsEventTarget, event: XFormsEvent):
        (JArrayList[XFormsEventObserver], JLinkedHashMap[String, XFormsEvent], JArrayList[XFormsEventObserver]) = {

        val doc = event.getTargetXBLContainer.getContainingDocument

        val boundaries = new JArrayList[XFormsEventObserver]
        val eventsForBoundaries = new JLinkedHashMap[String, XFormsEvent] // Map<String effectiveId, XFormsEvent event>
        val eventObservers = new JArrayList[XFormsEventObserver]

        val startObserver = targetObject match {
            case targetObject: XFormsEventObserver ⇒ targetObject
            case _ ⇒ targetObject.getParentEventObserver(doc) // why this is needed?
        }

        val ignoreObserver = (o: XFormsEventObserver) ⇒ o.isInstanceOf[XFormsRepeatControl] && (o ne targetObject) || o.isInstanceOf[XXFormsRootControl]
        val notReachedComponent = (o: XFormsEventObserver) ⇒ ! (o.isInstanceOf[XFormsComponentControl] && (o ne targetObject))

        // Iterator over all observers except those we always ignore
        val commonIterator = new ObserverIterator(startObserver, doc) filterNot (ignoreObserver)

        // Iterator over all the observers we need to handle
        val observerIterator =
            event match {
                case focusEvent @ (_: DOMFocusInEvent | _: DOMFocusOutEvent) ⇒
                    // Proper event propagation over scopes for focus events

                    val targetScope = targetObject.getScope(doc)
                    commonIterator filter (_.getScope(doc) == targetScope)

                case uiEvent: XFormsUIEvent ⇒
                    // Broken retargeting for other UI events

                    def addRetarget(o: XFormsEventObserver) {
                        boundaries.add(o);
                        eventsForBoundaries.put(o.getEffectiveId, null)
                    }

                    commonIterator map {o ⇒ if (! notReachedComponent(o)) addRetarget(o); o}

                case _ ⇒
                    // For other events, simply stop propagation at the component boundary
                    // This is broken too as it doesn't follow scopes!

                    commonIterator takeWhile (notReachedComponent)
            }

        eventObservers.addAll(observerIterator.toList.asJava)

        (boundaries, eventsForBoundaries, eventObservers)
    }

    // Iterator over a control's ancestors
    private class ObserverIterator(start: XFormsEventObserver, doc: XFormsContainingDocument) extends Iterator[XFormsEventObserver] {
        private var _next = start
        def hasNext = _next ne null
        def next() = {
            val result = _next
            _next = _next.getParentEventObserver(doc)
            result
        }
    }

    // Whether the control is hidden within a non-visible case or dialog
    private def isHidden(control: XFormsControl) = new AncestorIterator(control.parent) exists {
        case switchCase: XFormsCaseControl if ! switchCase.isVisible ⇒ true
        case dialog: XXFormsDialogControl if ! dialog.isVisible ⇒ true
        case _ ⇒ false
    }

    // Whether the control is focusable, that is it supports focus, is relevant, not read-only, and is not in a hidden case
    private def isFocusable(control: XFormsControl) = control match {
        case focusable: XFormsSingleNodeControl with FocusableTrait if focusable.isReadonly ⇒ false
        case focusable: FocusableTrait if focusable.isRelevant && ! isHidden(focusable) ⇒ true
        case _ ⇒ false
    }

    // Dispatch DOMFocusOut and DOMFocusIn
    private def focusOut(control: XFormsControl) = dispatch(control, DOM_FOCUS_OUT)
    private def focusIn(control: XFormsControl)  = dispatch(control, DOM_FOCUS_IN)

    private def dispatch(control: XFormsControl, eventName: String) =
        control.container.dispatchEvent(XFormsEventFactory.createEvent(control.containingDocument, eventName, control))

    // Find all ancestor container controls of the given control from leaf to root
    private def containers(control: XFormsControl) =
        new AncestorIterator(control.parent) collect
            { case container: XFormsContainerControl ⇒ container } toList

    // Ancestor controls and control from leaf to root excepting the root control
    private def containersAndSelf(control: XFormsControl) =
        control :: containers(control).init
}